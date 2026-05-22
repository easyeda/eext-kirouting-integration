@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

echo ============================================
echo   KiRouting Bridge Server - One-Click Start
echo ============================================
echo.

cd /d "%~dp0"

REM --- Configuration ---
set "REPO_BASE=https://raw.githubusercontent.com/easyeda/eext-kirouting-integration/main/bridge_server"
set "SERVER_DIR=%~dp0bridge_server"

REM --- Step 1: Check Python ---
echo [1/5] Checking Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo Python not found. Attempting to install via winget...
    winget install Python.Python.3.12 --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        echo.
        echo ERROR: Failed to install Python automatically.
        echo Please install Python 3.8+ manually from https://www.python.org/downloads/
        echo Make sure to check "Add Python to PATH" during installation.
        echo.
        pause
        exit /b 1
    )
    echo Python installed. You may need to restart this script for PATH to take effect.
    echo.
    pause
    exit /b 0
)
for /f "tokens=2" %%v in ('python --version 2^>^&1') do echo   Found Python %%v

REM --- Step 2: Download bridge_server files ---
echo.
echo [2/5] Downloading bridge server files...

if not exist "!SERVER_DIR!" mkdir "!SERVER_DIR!"

set "FILES=server.py routing_runner.py easyeda_to_kicad.py kicad_diff.py layer_mapping.py models.py coord_transform.py analysis.py verify_precision.py requirements.txt"

set "DOWNLOAD_OK=1"
for %%f in (%FILES%) do (
    if not exist "!SERVER_DIR!\%%f" (
        echo   Downloading %%f...
        curl -sL "%REPO_BASE%/%%f" -o "!SERVER_DIR!\%%f"
        if errorlevel 1 (
            set "DOWNLOAD_OK=0"
            echo   ERROR: Failed to download %%f
        )
    ) else (
        echo   %%f already exists, skipping
    )
)

if "!DOWNLOAD_OK!"=="0" (
    echo.
    echo ERROR: Some files failed to download. Please check your network connection.
    echo.
    pause
    exit /b 1
)
echo   All files OK

REM --- Step 3: Check pip dependencies ---
echo.
echo [3/5] Checking Python dependencies...

python -c "import fastapi; import uvicorn; import numpy" 2>nul
if errorlevel 1 (
    echo   Installing dependencies...
    pip install -r "!SERVER_DIR!\requirements.txt"
    if errorlevel 1 (
        echo.
        echo ERROR: Failed to install Python dependencies.
        echo Try running manually: pip install -r requirements.txt
        echo.
        pause
        exit /b 1
    )
)
echo   Dependencies OK

REM --- Step 4: Check KiCadRoutingTools ---
echo.
echo [4/5] Checking KiCadRoutingTools...

set "TOOLS_DIR=%~dp0KiCadRoutingTools"
if not exist "!TOOLS_DIR!\route.py" (
    echo   KiCadRoutingTools not found, downloading...
    set "ZIP_FILE=%~dp0KiCadRoutingTools.zip"
    curl -sL "https://github.com/drandyhaas/KiCadRoutingTools/archive/refs/heads/main.zip" -o "!ZIP_FILE!"
    if errorlevel 1 (
        echo.
        echo ERROR: Failed to download KiCadRoutingTools.
        echo Please check your network connection.
        echo.
        pause
        exit /b 1
    )
    echo   Extracting...
    powershell -Command "Expand-Archive -Path '!ZIP_FILE!' -DestinationPath '%~dp0' -Force"
    if errorlevel 1 (
        echo.
        echo ERROR: Failed to extract KiCadRoutingTools.
        echo.
        pause
        exit /b 1
    )
    ren "%~dp0KiCadRoutingTools-main" KiCadRoutingTools
    del "!ZIP_FILE!"
)
echo   KiCadRoutingTools OK

REM --- Step 5: Start server ---
echo.
echo [5/5] Starting bridge server...
echo.
echo ============================================
echo   Server running at http://localhost:8765
echo   Press Ctrl+C to stop
echo ============================================
echo.

cd /d "!SERVER_DIR!"
python server.py
pause
