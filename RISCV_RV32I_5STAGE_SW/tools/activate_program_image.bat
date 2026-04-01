@echo off
setlocal

if "%~1"=="" (
    echo [ERROR] No program image provided.
    echo Usage: %~nx0 ^<program_mem^> [program_label] [program_source]
    exit /b 1
)

for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"

set "PROGRAM_MEM=%~f1"
set "PROGRAM_LABEL=%~2"
set "PROGRAM_SRC=%~f3"
set "ACTIVE_MEM=%PROJECT_ROOT%\src\InstructionFORTIMING.mem"
set "ACTIVE_SRC=%PROJECT_ROOT%\src\InstructionFORTIMING.s"
set "ACTIVE_META=%PROJECT_ROOT%\src\ACTIVE_PROGRAM.txt"

if not defined PROGRAM_LABEL (
    for %%I in ("%PROGRAM_MEM%") do set "PROGRAM_LABEL=%%~nI"
)

if not exist "%PROGRAM_MEM%" (
    echo [ERROR] Program image not found: %PROGRAM_MEM%
    exit /b 1
)

copy /y "%PROGRAM_MEM%" "%ACTIVE_MEM%" >nul
if errorlevel 1 (
    echo [ERROR] Failed to activate program image.
    exit /b 1
)

if defined PROGRAM_SRC (
    if exist "%PROGRAM_SRC%" (
        copy /y "%PROGRAM_SRC%" "%ACTIVE_SRC%" >nul
        if errorlevel 1 (
            echo [ERROR] Failed to update active source mirror.
            exit /b 1
        )
    )
)

(
    echo Active program : %PROGRAM_LABEL%
    echo Program image  : %PROGRAM_MEM%
    if defined PROGRAM_SRC (
        if exist "%PROGRAM_SRC%" echo Program source : %PROGRAM_SRC%
        if not exist "%PROGRAM_SRC%" echo Program source : ^<missing^> %PROGRAM_SRC%
    ) else (
        echo Program source : ^<not provided^>
    )
    echo Activated at   : %DATE% %TIME%
) > "%ACTIVE_META%"

echo [OK] Active ROM image set to: %PROGRAM_LABEL%
echo      Image : %PROGRAM_MEM%
if defined PROGRAM_SRC if exist "%PROGRAM_SRC%" echo      Source: %PROGRAM_SRC%

exit /b 0
