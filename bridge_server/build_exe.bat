@echo off
echo ============================================
echo   Build KiCad Routing Bridge Server EXE
echo ============================================
echo.

cd /d "%~dp0"

python -c "import PyInstaller" 2>nul
if errorlevel 1 (
    echo Installing PyInstaller...
    pip install pyinstaller
    echo.
)

echo Building executable...
echo.

pyinstaller --onefile ^
    --name kirouting-integration ^
    --add-data "requirements.txt;." ^
    --hidden-import=uvicorn.logging ^
    --hidden-import=uvicorn.loops ^
    --hidden-import=uvicorn.loops.auto ^
    --hidden-import=uvicorn.protocols ^
    --hidden-import=uvicorn.protocols.http ^
    --hidden-import=uvicorn.protocols.http.auto ^
    --hidden-import=uvicorn.protocols.websockets ^
    --hidden-import=uvicorn.protocols.websockets.auto ^
    --hidden-import=uvicorn.lifespan ^
    --hidden-import=uvicorn.lifespan.on ^
    --hidden-import=kicad_parser ^
    --hidden-import=kicad_writer ^
    --hidden-import=route ^
    --hidden-import=grid_router ^
    --hidden-import=numpy ^
    server.py

echo.
if exist "dist\kirouting-integration.exe" (
    echo SUCCESS: dist\kirouting-integration.exe created
    echo.
    echo To run: dist\kirouting-integration.exe
) else (
    echo FAILED: Check the build output above for errors
)

pause
