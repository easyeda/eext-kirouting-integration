@echo off
echo ============================================
echo   KiCad Routing Bridge Server
echo ============================================
echo.

cd /d "%~dp0"

python -c "import fastapi" 2>nul
if errorlevel 1 (
    echo Installing dependencies...
    pip install -r requirements.txt
    echo.
)

echo Starting server on http://localhost:8765
echo Press Ctrl+C to stop
echo.

python server.py
pause
