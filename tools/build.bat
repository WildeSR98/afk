@echo off
chcp 1251 >nul
echo ==========================================
echo  Roblox AFK Keeper v3.2 - Builder
echo ==========================================
echo.

:: Root is one level up from tools\
set "ROOT=%~dp0.."
set "AHK_DIR="

if exist "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" (
    set "AHK_DIR=C:\Program Files\AutoHotkey\v2"
) else if exist "C:\Program Files\AutoHotkey\AutoHotkey.exe" (
    set "AHK_DIR=C:\Program Files\AutoHotkey"
) else if exist "%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey64.exe" (
    set "AHK_DIR=%LocalAppData%\Programs\AutoHotkey\v2"
)

if "%AHK_DIR%"=="" (
    echo AutoHotkey v2 not found!
    echo Install from https://www.autohotkey.com/
    pause
    exit /b 1
)

set "AHK2EXE=%AHK_DIR%\Compiler\Ahk2Exe.exe"
set "AHK2EXE_LOCAL=%~dp0Ahk2Exe\Ahk2Exe.exe"

if not exist "%AHK2EXE%" (
    if exist "%AHK2EXE_LOCAL%" (
        set "AHK2EXE=%AHK2EXE_LOCAL%"
    ) else (
        echo.
        echo Ahk2Exe not found. Attempting download...
        powershell -ExecutionPolicy Bypass -File "%~dp0download_ahk2exe.ps1"
        if errorlevel 1 (
            echo.
            echo FAILED TO DOWNLOAD Ahk2Exe automatically.
            echo.
            echo Please download it manually:
            echo 1. Open https://github.com/AutoHotkey/Ahk2Exe/releases
            echo 2. Download Ahk2Exe.zip from the latest release
            echo 3. Extract to: %ROOT%\Ahk2Exe\
            echo 4. Re-run build.bat
            pause
            exit /b 1
        )
        if exist "%AHK2EXE_LOCAL%" (
            set "AHK2EXE=%AHK2EXE_LOCAL%"
        ) else (
            echo Ahk2Exe still not found after download attempt.
            pause
            exit /b 1
        )
    )
)

:: [1/4] Generate activation codes (only if CodeData.ahk missing)
if not exist "%ROOT%\src\CodeData.ahk" (
    echo.
    echo [1/4] Generating activation codes...
    "%AHK_DIR%\AutoHotkey64.exe" "%~dp0generate_codes.ahk"
    if errorlevel 1 (
        echo Code generation failed.
        pause
        exit /b 1
    )
) else (
    echo [1/4] src\CodeData.ahk already exists. Skipping code generation.
)

:: [2/4] Copy runtime resources to dist\
echo.
echo [2/4] Copying resources...
if not exist "%ROOT%\dist" mkdir "%ROOT%\dist"
if not exist "%ROOT%\dist\resources" mkdir "%ROOT%\dist\resources"
if not exist "%ROOT%\dist\lang" mkdir "%ROOT%\dist\lang"

:: Copy lang INI files if they exist (generated from ahk lang files)
if exist "%ROOT%\dist\lang" (
    echo       lang\ folder ready.
)

:: NOTE: codes.bin is NO LONGER copied — codes are embedded in the EXE via src\CodeData.ahk
:: resources\ files are created/updated at runtime by the app itself
echo       Resources done.

:: [3/3] Build EXE
echo.
echo [3/3] Building EXE...
"%AHK2EXE%" /in "%ROOT%\RobloxAFKKeeper.ahk" /out "%ROOT%\dist\RobloxAFKKeeper.exe" /base "%AHK_DIR%\AutoHotkey64.exe" /compress 1
if errorlevel 1 (
    echo Build failed.
    pause
    exit /b 1
)

echo.
echo [Done]!
echo EXE: dist\RobloxAFKKeeper.exe
echo Activation codes: tools\codes.txt  (DO NOT publish this file)
echo.
pause
st process ahk
:: Better: run the obfuscator directly on the source, outputting to build_tmp
"%AHK_DIR%\AutoHotkey64.exe" "%~dp0obfuscate.ahk" "%ROOT%\RobloxAFKKeeper.ahk" "%BUILD_TMP%"
if errorlevel 1 (
    echo Obfuscation failed.
    pause
    exit /b 1
)

:: Copy resources and folders needed for compilation (like src, lib, lang, vendor) into build_tmp
xcopy "%ROOT%\lang" "%BUILD_TMP%\lang\" /s /e /y /i >nul
xcopy "%ROOT%\lib" "%BUILD_TMP%\lib\" /s /e /y /i >nul
xcopy "%ROOT%\vendor" "%BUILD_TMP%\vendor\" /s /e /y /i >nul
xcopy "%ROOT%\src" "%BUILD_TMP%\src\" /s /e /y /i >nul

:: Re-run obfuscator specifically for includes to overwrite the copied originals in build_tmp
"%AHK_DIR%\AutoHotkey64.exe" "%~dp0obfuscate.ahk" "%ROOT%\RobloxAFKKeeper.ahk" "%BUILD_TMP%"

:: [4/4] Build EXE
echo.
echo [4/4] Building EXE...
"%AHK2EXE%" /in "%BUILD_TMP%\RobloxAFKKeeper.ahk" /out "%ROOT%\dist\RobloxAFKKeeper.exe" /base "%AHK_DIR%\AutoHotkey64.exe" /compress 1
if errorlevel 1 (
    echo Build failed.
    pause
    exit /b 1
)

:: Cleanup
rmdir /s /q "%BUILD_TMP%"

echo.
echo [Done]!
echo EXE: dist\RobloxAFKKeeper.exe
echo Activation codes: tools\codes.txt  (DO NOT publish this file)
echo.
pause
