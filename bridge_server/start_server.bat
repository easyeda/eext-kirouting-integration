@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

echo ============================================
echo   KiRouting Bridge Server - One-Click Start
echo ============================================
echo.

cd /d "%~dp0"

REM --- Step 1: Check Python ---
echo [1/4] Checking Python...
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

REM --- Step 2: Check pip dependencies ---
echo.
echo [2/4] Checking Python dependencies...

python -c "import fastapi; import uvicorn; import numpy" 2>nul
if errorlevel 1 (
    echo   Installing dependencies...
    pip install -r requirements.txt
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

REM --- Step 3: Check KiCadRoutingTools ---
echo.
echo [3/4] Checking KiCadRoutingTools...

set "TOOLS_DIR=%~dp0..\..\KiCadRoutingTools"
if not exist "%TOOLS_DIR%\route.py" (
    echo   KiCadRoutingTools not found, cloning from GitHub...
    git clone https://github.com/drandyhaas/KiCadRoutingTools.git "%TOOLS_DIR%"
    if errorlevel 1 (
        echo.
        echo ERROR: Failed to clone KiCadRoutingTools.
        echo Please install Git from https://git-scm.com/ or clone manually:
        echo   git clone https://github.com/drandyhaas/KiCadRoutingTools.git
        echo.
        pause
        exit /b 1
    )
)
echo   KiCadRoutingTools OK

REM --- Check Rust router (optional) ---
set "RUST_LIB=%TOOLS_DIR%\rust_router\rust_astar_router.pyd"
if not exist "%RUST_LIB%" (
    set "RUST_LIB=%TOOLS_DIR%\rust_router\rust_astar_router.so"
)
if not exist "%RUST_LIB%" (
    where cargo >nul 2>&1
    if errorlevel 1 (
        echo   Note: Rust not found, will use Python fallback mode.
        echo   For better performance, install Rust from https://rustup.rs/
    ) else (
        echo   Building Rust router...
        cd /d "%TOOLS_DIR%"
        python build_router.py
        if errorlevel 1 (
            echo   WARNING: Rust router build failed. Will use Python fallback mode.
        ) else (
            echo   Rust router built successfully
        )
        cd /d "%~dp0"
    )
) else (
    echo   Rust router OK
)

REM --- Step 4: Start server ---
echo.
echo [4/4] Starting bridge server...
echo.
echo ============================================
echo   Server running at http://localhost:8765
echo   Press Ctrl+C to stop
echo ============================================
echo.

python server.py
pause
