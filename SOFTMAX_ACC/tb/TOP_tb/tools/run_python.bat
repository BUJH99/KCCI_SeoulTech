@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..\..\..") do set "PROJECT_ROOT=%%~fI"
set "LOCAL_PY=%PROJECT_ROOT%\.venv\Scripts\python.exe"

if exist "%LOCAL_PY%" (
    "%LOCAL_PY%" %*
    exit /b %ERRORLEVEL%
)

where py >nul 2>nul
if not errorlevel 1 (
    py -3 %*
    exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
    python %*
    exit /b %ERRORLEVEL%
)

echo [TB][ERROR] Python launcher not found.
echo [TB][ERROR] Checked local venv: %LOCAL_PY%
echo [TB][ERROR] Checked PATH commands: py -3, python
exit /b 9009
