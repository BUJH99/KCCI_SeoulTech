@echo off
setlocal

for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
for %%I in ("%~dp0..\..\..") do set "REPO_ROOT=%%~fI"

set "NO_PAUSE="
:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="--no-pause" set "NO_PAUSE=--no-pause"
shift
goto parse_args

:args_done
set "ACTIVATE_BAT=%PROJECT_ROOT%\tools\activate_program_image.bat"
set "TETRIS_DIR=%PROJECT_ROOT%\src\programs\tetris"
set "TETRIS_MEM=%TETRIS_DIR%\Tetris.mem"
set "TETRIS_SRC=%TETRIS_DIR%\Tetris.s"
set "BUILD_BAT=%REPO_ROOT%\templates\contexts\vivado\adapters\bat\vivado_run_build_flow.bat"

if not exist "%TETRIS_MEM%" (
    echo [ERROR] Tetris.mem not found.
    echo         Expected: %TETRIS_MEM%
    echo         Port or drop a playable RV32I image into src\programs\tetris first.
    exit /b 1
)

call "%ACTIVATE_BAT%" "%TETRIS_MEM%" "troglobit-micro-tetris" "%TETRIS_SRC%"
if errorlevel 1 exit /b %errorlevel%

call "%BUILD_BAT%" "%PROJECT_ROOT%" %NO_PAUSE%
exit /b %errorlevel%
