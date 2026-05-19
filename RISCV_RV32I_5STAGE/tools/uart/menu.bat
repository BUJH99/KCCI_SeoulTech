@echo off
setlocal EnableExtensions EnableDelayedExpansion

for %%I in ("%~dp0..\..") do set "PROJECT_ROOT=%%~fI"
set "TOOLS_DIR=%PROJECT_ROOT%\tools"

call :Main %*
set "MENU_EXIT_CODE=%ERRORLEVEL%"
if not "%MENU_EXIT_CODE%"=="0" (
  echo.
  echo [FAIL] UART tool menu exited with %MENU_EXIT_CODE%.
  if "%~1"=="" pause
)
exit /b %MENU_EXIT_CODE%

:Main
call :FindPython
if errorlevel 1 exit /b 1
call :LoadDefaults
if errorlevel 1 exit /b 1

if /I "%~1"=="help" goto Help
if /I "%~1"=="/?" goto Help
if /I "%~1"=="-h" goto Help
if /I "%~1"=="--help" goto Help

if /I "%~1"=="soc" goto CmdSoc
if /I "%~1"=="bootrom" goto CmdBootrom
if /I "%~1"=="app" goto CmdApp
if /I "%~1"=="data" goto CmdPacket
if /I "%~1"=="image" goto CmdPacket
if /I "%~1"=="packet" goto CmdPacket
if /I "%~1"=="send" goto CmdSend
if /I "%~1"=="download" goto CmdDownload
if /I "%~1"=="xsim" goto CmdXsim
if /I "%~1"=="gui" goto CmdGui

if not "%~1"=="" (
  echo [FAIL] Unknown command: %~1
  echo.
  goto Help
)

:Menu
echo.
echo ============================================================
echo   RISCV_RV32I_5STAGE UART Bootloader Tools
echo ============================================================
echo   [1] SoC Map
echo   [2] BootROM
echo   [3] Default App
echo   [4] Custom App
echo   [5] Raw App -^> UART DATA
echo   [6] Send UART DATA
echo   [7] Build + Send
echo   [8] XSIM
echo   [9] Paths
echo   [G] Launch GUI
echo   [H] Help
echo   [Q] Quit
echo.
set "CHOICE="
set /p "CHOICE=Select menu: "

if /I "%CHOICE%"=="Q" exit /b 0
if /I "%CHOICE%"=="H" call :HelpText & call :PauseAndMenu
if "%CHOICE%"=="1" call :Soc & call :PauseAndMenu
if "%CHOICE%"=="2" call :Bootrom & call :PauseAndMenu
if "%CHOICE%"=="3" call :BuildApp "%DEFAULT_APP%" "%DEFAULT_APP_NAME%" & call :PauseAndMenu
if "%CHOICE%"=="4" call :PromptBuildApp & call :PauseAndMenu
if "%CHOICE%"=="5" call :PromptPacket & call :PauseAndMenu
if "%CHOICE%"=="6" call :PromptSend & call :PauseAndMenu
if "%CHOICE%"=="7" call :PromptDownload & call :PauseAndMenu
if "%CHOICE%"=="8" call :Xsim & call :PauseAndMenu
if "%CHOICE%"=="9" call :ShowPaths & call :PauseAndMenu
if /I "%CHOICE%"=="G" call :Gui & call :PauseAndMenu

echo [WARN] Unknown selection: %CHOICE%
goto Menu

:CmdSoc
call :Soc
exit /b %ERRORLEVEL%

:CmdBootrom
call :Bootrom
exit /b %ERRORLEVEL%

:CmdApp
set "APP_PATH=%~2"
set "APP_NAME=%~3"
if "%APP_PATH%"=="" set "APP_PATH=%DEFAULT_APP%"
if "%APP_NAME%"=="" (
  if /I "%APP_PATH%"=="%DEFAULT_APP%" (
    set "APP_NAME=%DEFAULT_APP_NAME%"
  ) else (
    for %%I in ("%APP_PATH%") do set "APP_NAME=%%~nI"
  )
)
call :BuildApp "%APP_PATH%" "%APP_NAME%"
exit /b %ERRORLEVEL%

:CmdPacket
if "%~2"=="" (
  echo [FAIL] data command requires raw app path.
  echo Usage: %~nx0 data raw_app.bin uart_data.bin [uart_data.hex] [load_addr] [entry]
  exit /b 1
)
if "%~3"=="" (
  echo [FAIL] data command requires UART DATA output path.
  echo Usage: %~nx0 data raw_app.bin uart_data.bin [uart_data.hex] [load_addr] [entry]
  exit /b 1
)
set "PAYLOAD=%~2"
set "PACKET_BIN=%~3"
set "PACKET_HEX=%~4"
set "LOAD_ADDR=%~5"
set "ENTRY_ADDR=%~6"
if "%LOAD_ADDR%"=="" set "LOAD_ADDR=%DEFAULT_LOAD_ADDR%"
if "%ENTRY_ADDR%"=="" set "ENTRY_ADDR=%DEFAULT_ENTRY_ADDR%"
call :Packet "%PAYLOAD%" "%PACKET_BIN%" "%PACKET_HEX%" "%LOAD_ADDR%" "%ENTRY_ADDR%"
exit /b %ERRORLEVEL%

:CmdSend
if "%~2"=="" (
  echo [FAIL] send command requires serial port.
  echo Usage: %~nx0 send COM5 [uart_data.bin] [baud]
  exit /b 1
)
set "PORT=%~2"
set "PACKET_BIN=%~3"
set "BAUD=%~4"
if "%PACKET_BIN%"=="" set "PACKET_BIN=%DEFAULT_PACKET%"
if "%BAUD%"=="" set "BAUD=%DEFAULT_BAUD%"
call :Send "%PORT%" "%PACKET_BIN%" "%BAUD%"
exit /b %ERRORLEVEL%

:CmdDownload
if "%~2"=="" (
  echo [FAIL] download command requires serial port.
  echo Usage: %~nx0 download COM5 [app.c] [name] [baud]
  exit /b 1
)
set "PORT=%~2"
set "APP_PATH=%~3"
set "APP_NAME=%~4"
set "BAUD=%~5"
if "%APP_PATH%"=="" set "APP_PATH=%DEFAULT_APP%"
if "%APP_NAME%"=="" (
  if /I "%APP_PATH%"=="%DEFAULT_APP%" (
    set "APP_NAME=%DEFAULT_APP_NAME%"
  ) else (
    for %%I in ("%APP_PATH%") do set "APP_NAME=%%~nI"
  )
)
if "%BAUD%"=="" set "BAUD=%DEFAULT_BAUD%"
call :Download "%PORT%" "%APP_PATH%" "%APP_NAME%" "%BAUD%"
exit /b %ERRORLEVEL%

:CmdXsim
call :Xsim
exit /b %ERRORLEVEL%

:CmdGui
call :Gui
exit /b %ERRORLEVEL%

:FindPython
where python >nul 2>nul
if not errorlevel 1 (
  set "PYTHON=python"
  exit /b 0
)

where py >nul 2>nul
if not errorlevel 1 (
  set "PYTHON=py -3"
  exit /b 0
)

echo [FAIL] Python was not found on PATH.
exit /b 1

:LoadDefaults
for /f "usebackq tokens=1,* delims==" %%A in (`%PYTHON% "%TOOLS_DIR%\common\project_config.py" --bat`) do (
  set "%%A=%%B"
)
if not defined DEFAULT_APP (
  echo [FAIL] Failed to load tool defaults.
  exit /b 1
)
exit /b 0

:Soc
echo [RUN] Generate SoC artifacts
call %PYTHON% "%TOOLS_DIR%\soc\generate_soc_artifacts.py"
exit /b %ERRORLEVEL%

:Bootrom
echo [RUN] Build BootRom
call %PYTHON% "%TOOLS_DIR%\firmware\build_bootrom.py"
exit /b %ERRORLEVEL%

:BuildApp
set "APP_PATH=%~1"
set "APP_NAME=%~2"
if "%APP_NAME%"=="" for %%I in ("%APP_PATH%") do set "APP_NAME=%%~nI"
echo [RUN] Build app: %APP_NAME%
call %PYTHON% "%TOOLS_DIR%\firmware\build_uart_app.py" --app "%APP_PATH%" --name "%APP_NAME%"
exit /b %ERRORLEVEL%

:Packet
set "PAYLOAD=%~1"
set "PACKET_BIN=%~2"
set "PACKET_HEX=%~3"
set "LOAD_ADDR=%~4"
set "ENTRY_ADDR=%~5"
if "%LOAD_ADDR%"=="" set "LOAD_ADDR=%DEFAULT_LOAD_ADDR%"
if "%ENTRY_ADDR%"=="" set "ENTRY_ADDR=%DEFAULT_ENTRY_ADDR%"

echo [RUN] Make UART DATA
if "%PACKET_HEX%"=="" (
  call %PYTHON% "%TOOLS_DIR%\uart\make_loader_packet.py" "%PAYLOAD%" "%PACKET_BIN%" --load-addr "%LOAD_ADDR%" --entry "%ENTRY_ADDR%"
) else (
  call %PYTHON% "%TOOLS_DIR%\uart\make_loader_packet.py" "%PAYLOAD%" "%PACKET_BIN%" --packet-hex "%PACKET_HEX%" --load-addr "%LOAD_ADDR%" --entry "%ENTRY_ADDR%"
)
exit /b %ERRORLEVEL%

:Send
set "PORT=%~1"
set "PACKET_BIN=%~2"
set "BAUD=%~3"
if "%BAUD%"=="" set "BAUD=%DEFAULT_BAUD%"
echo [RUN] Send UART DATA to %PORT% at %BAUD%
call %PYTHON% "%TOOLS_DIR%\uart\send_loader_packet.py" "%PORT%" "%PACKET_BIN%" --baud "%BAUD%"
exit /b %ERRORLEVEL%

:Download
set "PORT=%~1"
set "APP_PATH=%~2"
set "APP_NAME=%~3"
set "BAUD=%~4"
if "%BAUD%"=="" set "BAUD=%DEFAULT_BAUD%"
echo [RUN] Build + send %APP_NAME% to %PORT%
call %PYTHON% "%TOOLS_DIR%\uart\download_uart_app.py" "%PORT%" --app "%APP_PATH%" --name "%APP_NAME%" --baud "%BAUD%"
exit /b %ERRORLEVEL%

:Xsim
echo [RUN] UART InstDma XSIM
call %PYTHON% "%TOOLS_DIR%\sim\xsim_runner.py" uart_inst_dma
exit /b %ERRORLEVEL%

:Gui
echo [RUN] UART Bootloader GUI
call %PYTHON% "%TOOLS_DIR%\uart\uart_bootloader_gui.py"
exit /b %ERRORLEVEL%

:PromptBuildApp
set "APP_PATH="
set "APP_NAME="
set /p "APP_PATH=App C path [%DEFAULT_APP%]: "
if "%APP_PATH%"=="" set "APP_PATH=%DEFAULT_APP%"
set /p "APP_NAME=Output name [auto]: "
if "%APP_NAME%"=="" (
  if /I "%APP_PATH%"=="%DEFAULT_APP%" (
    set "APP_NAME=%DEFAULT_APP_NAME%"
  ) else (
    for %%I in ("%APP_PATH%") do set "APP_NAME=%%~nI"
  )
)
call :BuildApp "%APP_PATH%" "%APP_NAME%"
exit /b %ERRORLEVEL%

:PromptPacket
set "PAYLOAD="
set "PACKET_BIN="
set "PACKET_HEX="
set "LOAD_ADDR="
set "ENTRY_ADDR="
set /p "PAYLOAD=Raw app path: "
if "%PAYLOAD%"=="" (
  echo [FAIL] Raw app path is required.
  exit /b 1
)
set /p "PACKET_BIN=UART DATA .bin path: "
if "%PACKET_BIN%"=="" (
  echo [FAIL] UART DATA output path is required.
  exit /b 1
)
set /p "PACKET_HEX=Optional UART DATA .hex path [blank=skip]: "
set /p "LOAD_ADDR=Load address [%DEFAULT_LOAD_ADDR%]: "
set /p "ENTRY_ADDR=Entry address [%DEFAULT_ENTRY_ADDR%]: "
if "%LOAD_ADDR%"=="" set "LOAD_ADDR=%DEFAULT_LOAD_ADDR%"
if "%ENTRY_ADDR%"=="" set "ENTRY_ADDR=%DEFAULT_ENTRY_ADDR%"
call :Packet "%PAYLOAD%" "%PACKET_BIN%" "%PACKET_HEX%" "%LOAD_ADDR%" "%ENTRY_ADDR%"
exit /b %ERRORLEVEL%

:PromptSend
set "PORT="
set "PACKET_BIN="
set "BAUD="
set /p "PORT=Serial port, e.g. COM5: "
if "%PORT%"=="" (
  echo [FAIL] Serial port is required.
  exit /b 1
)
set /p "PACKET_BIN=UART DATA path [%DEFAULT_PACKET%]: "
if "%PACKET_BIN%"=="" set "PACKET_BIN=%DEFAULT_PACKET%"
set /p "BAUD=Baud [%DEFAULT_BAUD%]: "
if "%BAUD%"=="" set "BAUD=%DEFAULT_BAUD%"
call :Send "%PORT%" "%PACKET_BIN%" "%BAUD%"
exit /b %ERRORLEVEL%

:PromptDownload
set "PORT="
set "APP_PATH="
set "APP_NAME="
set "BAUD="
set /p "PORT=Serial port, e.g. COM5: "
if "%PORT%"=="" (
  echo [FAIL] Serial port is required.
  exit /b 1
)
set /p "APP_PATH=App C path [%DEFAULT_APP%]: "
if "%APP_PATH%"=="" set "APP_PATH=%DEFAULT_APP%"
set /p "APP_NAME=Output name [%DEFAULT_APP_NAME% for default app, auto otherwise]: "
if "%APP_NAME%"=="" (
  if /I "%APP_PATH%"=="%DEFAULT_APP%" (
    set "APP_NAME=%DEFAULT_APP_NAME%"
  ) else (
    for %%I in ("%APP_PATH%") do set "APP_NAME=%%~nI"
  )
)
set /p "BAUD=Baud [%DEFAULT_BAUD%]: "
if "%BAUD%"=="" set "BAUD=%DEFAULT_BAUD%"
call :Download "%PORT%" "%APP_PATH%" "%APP_NAME%" "%BAUD%"
exit /b %ERRORLEVEL%

:ShowPaths
echo Project root : .
echo Default app  : %DEFAULT_APP%
echo Default name : %DEFAULT_APP_NAME%
echo UART DATA    : %DEFAULT_PACKET%
echo Baud         : %DEFAULT_BAUD%
echo BootRom mem  : src\timing_programs\uart_bootrom.mem
echo App output   : output\uart_app
echo XSIM output  : output\uart_inst_dma_xsim
exit /b 0

:Help
call :HelpText
exit /b 0

:HelpText
echo.
echo Usage:
echo   tools\uart\menu.bat
echo   tools\uart\menu.bat soc
echo   tools\uart\menu.bat bootrom
echo   tools\uart\menu.bat app [app.c] [name]
echo   tools\uart\menu.bat data raw_app.bin uart_data.bin [uart_data.hex] [load_addr] [entry]
echo   tools\uart\menu.bat send COM5 [uart_data.bin] [baud]
echo   tools\uart\menu.bat download COM5 [app.c] [name] [baud]
echo   tools\uart\menu.bat xsim
echo   tools\uart\menu.bat gui
echo.
echo Common flow:
echo   tools\uart\menu.bat bootrom
echo   tools\uart\menu.bat app
echo   tools\uart\menu.bat xsim
echo   tools\uart\menu.bat download COM5
echo   tools\uart\menu.bat gui
echo.
exit /b 0

:PauseAndMenu
set "LAST_STATUS=%ERRORLEVEL%"
echo.
if not "%LAST_STATUS%"=="0" echo [WARN] Last command exited with %LAST_STATUS%.
pause
goto Menu
