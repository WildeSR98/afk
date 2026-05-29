; ============================================================
;  lib\TrayMenu.ahk
;  System tray integration
; ============================================================

SetupTray() {
    A_IconHidden := false
    A_IconTip := "Roblox AFK Keeper " APP_VERSION
    TraySetIcon("shell32.dll", 44)
    A_TrayMenu.Delete()
    A_TrayMenu.Add(L("Start") " / " L("Stop"), ObjBindMethod(AFKEngine, "Toggle"))
    A_TrayMenu.Add(L("ToTray"), ShowGuiFromTray)
    A_TrayMenu.Add()
    A_TrayMenu.Add("Exit", ExitHandler)
    A_TrayMenu.Default := L("ToTray")
    A_TrayMenu.ClickCount := 2
}

ShowGuiFromTray(*) {
    global appGui
    if (IsObject(appGui)) {
        appGui.Show()
        WinActivate("ahk_id " appGui.Hwnd)
    }
}

HideToTray(*) {
    global appGui
    if (IsObject(appGui))
        appGui.Hide()
    TrayTip("Running in background. Press " ConfigManager.HotkeyToggle " to start/stop.", "Roblox AFK Keeper", "Iconi")
}

OnClosing(*) {
    HideToTray()
}

ExitHandler(*) {
    global gdipToken

    ; 1. Остановить все таймеры
    AFKEngine.Stop()
    ReconnectManager.Stop()

    ; 2. Освободить GDI+
    if (gdipToken) {
        DllCall("gdiplus\GdiplusShutdown", "Ptr", gdipToken)
        gdipToken := 0
    }

    ; 3. Завершить
    ExitApp()
}
