#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

; ============================================================
;  Roblox AFK Keeper v3.2
;  AutoHotkey v2 Edition — Modular
; ============================================================
global APP_VERSION := "v3.2"

#Include lang\lang_en.ahk
#Include lang\lang_ru.ahk
#Include vendor\OCR.ahk
#Include lib\LangUtils.ahk
#Include lib\WindowUtils.ahk
#Include lib\GDIPlus.ahk
#Include lib\Activation.ahk
#Include lib\AFKCore.ahk
#Include lib\Reconnect.ahk
#Include lib\TrayMenu.ahk
#Include src\CodeData.ahk

; ---------- Paths ----------
global LICENSE_FILE := A_ScriptDir "\resources\license.dat"
global TEMPLATE_PNG := A_ScriptDir "\resources\reconnect_template.png"
global SETTINGS_INI := A_ScriptDir "\resources\settings.ini"

; Ensure required folders exist (critical after update or fresh install)
EnsureDirectories() {
    if (!DirExist(A_ScriptDir "\resources"))
        DirCreate(A_ScriptDir "\resources")
}
EnsureDirectories()

; ---------- State ----------
global currentLang       := "ru"
global isActivated       := false
global appGui            := ""
global activationGui     := ""
global afkRunning        := false
global reconnectRunning  := false
global gdipToken         := 0
global robloxHwnd        := 0

; ============================================================
;  LOG
; ============================================================
LogMsg(msg) {
    global appGui
    if (!IsObject(appGui))
        return
    timeStr := FormatTime(,"HH:mm:ss")
    appGui["LogEdit"].Value .= "[" timeStr "] " msg "`r`n"
    try SendMessage(0x115, 7, 0, appGui["LogEdit"])
}

UpdateReconnectStatus() {
    global appGui
    if (!IsObject(appGui))
        return
    if (FileExist(TEMPLATE_PNG))
        appGui["ReconnectStatus"].Text := L("TemplateFound")
    else
        appGui["ReconnectStatus"].Text := L("AutoSearchEnabled")
}

; ============================================================
;  MAIN GUI
; ============================================================
ShowMainWindow() {
    global appGui
    appGui := Gui("+MinSize520x700", L("WindowTitle"))
    appGui.SetFont("s10", "Segoe UI")
    appGui.BackColor := "FFFFFF"
    appGui.MarginX := 15
    appGui.MarginY := 10

    ; Language button (top right)
    langBtn := appGui.AddButton("x460 y12 vLangBtn", L("LangBtn"))
    langBtn.OnEvent("Click", ToggleLanguage)

    ; Hotkeys info
    appGui.AddText("xm y10 w400 Center c808080", L("Hotkeys")).SetFont("s9")

    ; Status
    st := appGui.AddText("vStatusText xm y+8 w470 Center cFF0000", L("StatusStopped"))
    st.SetFont("s10 Bold")

    ; Settings GroupBox
    appGui.AddGroupBox("xm y+15 w470 h380 vSettingsBox", L("Settings"))

    ; Interval
    appGui.AddText("vIntervalLabel xm+10 yp+20", L("Interval"))
    appGui.AddEdit("vIntervalEdit x+5 w60 Number", "120")

    ; Background mode
    bgCheck := appGui.AddCheckbox("vBgCheck xm+10 y+12", L("BgMode"))
    bgCheck.OnEvent("Click", OnBgToggle)
    appGui.AddText("vBgWarn xm+10 y+2 w430 cFF8000", L("BgWarning")).SetFont("s8")

    ; Only active
    appGui.AddCheckbox("vActiveCheck xm+10 y+10 Checked", L("OnlyActive"))

    ; Activity type
    appGui.AddText("vActivityLabel xm+10 y+15", L("ActivityType"))
    appGui.AddRadio("vRbMouse xm+10 y+5 Checked Group", L("MouseMove"))
    appGui.AddRadio("vRbShift xm+10 y+5", L("ShiftKey"))
    appGui.AddRadio("vRbScroll xm+10 y+5", L("ScrollLock"))

    ; Separator
    appGui.AddText("xm+10 y+15 w430 h1 +0x10")

    ; Reconnect
    rcCheck := appGui.AddCheckbox("vReconnectCheck xm+10 y+10 Checked", L("ReconnectCheck"))
    rcCheck.OnEvent("Click", OnReconnectToggle)
    appGui.AddButton("vCaptureBtn x380 yp w110", L("CaptureBtn")).OnEvent("Click", CaptureTemplatePrompt)
    appGui.AddText("vReconnectStatus xm+10 y+5 w430 c808080", L("AutoSearchEnabled")).SetFont("s8")

    ; Control buttons
    appGui.AddButton("vStartBtn xm+60 y+25 w100", L("Start")).OnEvent("Click", StartAFK)
    appGui.AddButton("vStopBtn x+20 w100 Disabled", L("Stop")).OnEvent("Click", StopAFK)
    appGui.AddButton("vTrayBtn x+20 w100", L("ToTray")).OnEvent("Click", HideToTray)

    ; Log
    appGui.AddText("vLogLabel xm y+20", L("LogLabel"))
    appGui.AddEdit("vLogEdit xm y+5 w470 h150 ReadOnly -Wrap VScroll")

    appGui.OnEvent("Close", OnClosing)
    appGui.Show("AutoSize Center")
}

; ============================================================
;  GUI EVENTS
; ============================================================
ToggleLanguage(*) {
    global appGui, currentLang
    currentLang := currentLang = "ru" ? "en" : "ru"
    LoadLanguage(currentLang)

    appGui.Title := L("WindowTitle")
    appGui["LangBtn"].Text := L("LangBtn")
    appGui["HotkeysLabel"].Text := L("Hotkeys")
    appGui["StatusText"].Text := afkRunning ? L("StatusRunning") : L("StatusStopped")
    appGui["StatusText"].Opt(afkRunning ? "+c00AA00" : "+cFF0000")
    appGui["SettingsBox"].Text := L("Settings")
    appGui["IntervalLabel"].Text := L("Interval")
    appGui["BgCheck"].Text := L("BgMode")
    appGui["BgWarn"].Text := L("BgWarning")
    appGui["ActiveCheck"].Text := L("OnlyActive")
    appGui["ActivityLabel"].Text := L("ActivityType")
    appGui["RbMouse"].Text := L("MouseMove")
    appGui["RbShift"].Text := L("ShiftKey")
    appGui["RbScroll"].Text := L("ScrollLock")
    appGui["ReconnectCheck"].Text := L("ReconnectCheck")
    appGui["CaptureBtn"].Text := L("CaptureBtn")
    appGui["LogLabel"].Text := L("LogLabel")
    appGui["StartBtn"].Text := L("Start")
    appGui["StopBtn"].Text := L("Stop")
    appGui["TrayBtn"].Text := L("ToTray")
    UpdateReconnectStatus()
}

OnBgToggle(ctrl, *) {
    global appGui
    isBg := ctrl.Value
    appGui["ActiveCheck"].Enabled := !isBg
    appGui["RbMouse"].Enabled := !isBg
    if (isBg && appGui["RbMouse"].Value) {
        appGui["RbShift"].Value := 1
    }
}

OnReconnectToggle(ctrl, *) {
    if (ctrl.Value) {
        StartReconnect()
    } else {
        StopReconnect()
    }
}

; ============================================================
;  HOTKEYS
; ============================================================
SetupHotkeys() {
    Hotkey("F10", ToggleAFK)
    Hotkey("F8", CaptureTemplate)
}

; ============================================================
;  ENTRY POINT
; ============================================================
if (!CheckActivation()) {
    ; Activation window is shown; wait for user
} else {
    ShowMainWindow()
    SetupTray()
    SetupHotkeys()
}
