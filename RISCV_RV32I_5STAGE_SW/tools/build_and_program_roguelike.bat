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
set "ROGUELIKE_DIR=%PROJECT_ROOT%\src\programs\roguelike"
set "ROGUELIKE_MEM=%ROGUELIKE_DIR%\Roguelike.mem"
set "ROGUELIKE_SRC=%ROGUELIKE_DIR%\Roguelike.s"
set "FLOW_BAT=%REPO_ROOT%\templates\contexts\vivado\adapters\bat\vivado_run_build_and_program.bat"

if not exist "%ROGUELIKE_MEM%" (
    echo [ERROR] Roguelike.mem not found.
    echo         Expected: %ROGUELIKE_MEM%
    echo         Build the playable RV32I image into src\programs\roguelike first.
    exit /b 1
)

call "%ACTIVATE_BAT%" "%ROGUELIKE_MEM%" "strogue-micro-roguelike" "%ROGUELIKE_SRC%"
if errorlevel 1 exit /b %errorlevel%

call "%FLOW_BAT%" "%PROJECT_ROOT%" %NO_PAUSE%
exit /b %errorlevel%
