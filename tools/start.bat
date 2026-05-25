@echo off
:: Запуск Roblox AFK Keeper (исходник AHK)
set "ROOT=%~dp0.."
set "AHK_EXE="
for %%P in (
    "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
    "C:\Program Files\AutoHotkey\AutoHotkey64.exe"
    "C:\Program Files\AutoHotkey\AutoHotkey.exe"
) do (
    if exist %%P (
        set "AHK_EXE=%%~P"
        goto :run
    )
)
echo AutoHotkey не найден. Скачайте с https://www.autohotkey.com/
pause & exit /b 1
:run
"%AHK_EXE%" "%ROOT%\RobloxAFKKeeper.ahk"
