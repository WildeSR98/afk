; ============================================================
;  lib\TrayMenu.ahk
;  System tray integration
; ============================================================

SetupTray() {
    A_IconHidden := false
    A_IconTip := "Roblox AFK Keeper v3.2"
    TraySetIcon("shell32.dll", 44)
    A_TrayMenu.Delete()
    A_TrayMenu.Add(L("Start") " / " L("Stop"), ToggleAFK)
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
    TrayTip("Roblox AFK Keeper", "Running in background. Press F10 to start/stop.")
}

OnClosing(*) {
    HideToTray()
}

ExitHandler(*) {
    ExitApp()
}
