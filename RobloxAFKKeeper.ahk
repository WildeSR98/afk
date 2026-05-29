#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

; ============================================================
;  Roblox AFK Keeper v3.2
;  AutoHotkey v2 Edition — Modular (Modern UI Auto-Grid)
; ============================================================
global APP_VERSION := "v3.2"

#Include lang\lang_en.ahk
#Include lang\lang_ru.ahk
#Include vendor\OCR.ahk
#Include lib\Config.ahk
#Include lib\LangUtils.ahk
#Include lib\WindowUtils.ahk
#Include lib\GDIPlus.ahk
#Include lib\Activation.ahk
#Include lib\AFKCore.ahk
#Include lib\Reconnect.ahk
#Include lib\TrayMenu.ahk
#Include lib\Updater.ahk
#Include src\CodeData.ahk

; ---------- Paths ----------
global LICENSE_FILE := A_ScriptDir "\resources\license.dat"
global TEMPLATE_PNG := A_ScriptDir "\resources\reconnect_template.png"
global SETTINGS_INI := A_ScriptDir "\resources\settings.ini"

; Ensure required folders exist (critical after update or fresh install)
EnsureDirectories() {
    if (!DirExist(A_ScriptDir "\resources"))
        DirCreate(A_ScriptDir "\resources")
    if (!DirExist(A_ScriptDir "\data"))
        DirCreate(A_ScriptDir "\data")
}
EnsureDirectories()

; ---------- State ----------
global currentLang := "ru"
global isActivated := false
global appGui := ""
global activationGui := ""
global afkRunning := false
global reconnectRunning := false
global gdipToken := 0
global robloxHwnd := 0

; UI toggle states (used instead of checkbox .Value in background mode)
global bgState := 0   ; 0 = off, 1 = on
global activeState := 1   ; 0 = off, 1 = on
global recState := 1   ; 0 = off, 1 = on
global isRunningState := 0   ; 0 = stopped, 1 = running

; UI button references (set in ShowMainWindow, used in toggle handlers)
global btnToggleBg := ""
global btnToggleActive := ""
global btnToggleRec := ""
global btnMaster := ""
global txtStatus := ""
global editInt := ""

; ============================================================
;  LOG
; ============================================================
LogMsg(msg) {
    global appGui
    if (!IsObject(appGui))
        return
    timeStr := FormatTime(, "HH:mm:ss")
    fullMsg := "[" timeStr "] " msg

    if (HasProp(appGui, "LogList")) {
        appGui["LogList"].Add(, fullMsg)
        appGui["LogList"].Modify(appGui["LogList"].GetCount(), "Vis")
    } else if (HasProp(appGui, "LogEdit")) {
        appGui["LogEdit"].Value .= fullMsg "`r`n"
        try SendMessage(0x115, 7, 0, appGui["LogEdit"])
    }

    try FileAppend(fullMsg "`n", A_ScriptDir "\data\afk.log", "UTF-8")
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
;  MAIN GUI — Cyberpunk Dark UI (Auto-Grid & No Text Cut)
; ============================================================
ShowMainWindow() {
    global appGui, bgState, activeState, recState, isRunningState
    global btnToggleBg, btnToggleActive, btnToggleRec, btnMaster, txtStatus, editInt

    ; Окно расширено до w500 h720, чтобы вместить длинные текстовые строки
    appGui := Gui("-MinimizeBox -MaximizeBox +Border", L("WindowTitle"))
    appGui.BackColor := "121212"
    appGui.SetFont("s9 cE0E0E0", "Segoe UI")

    ; ── Top bar ──
    appGui.SetFont("s8 c555555")
    hotkeysText := StrReplace(StrReplace(L("Hotkeys"), "{1}", ConfigManager.HotkeyToggle), "{2}", ConfigManager.HotkeyCapture)
    appGui.AddText("vHotkeysLabel x20 y15 w320 h20", hotkeysText)

    langBtn := appGui.AddButton("-Theme vLangBtn x445 y10 w35 h22 +Background1A1A1A", L("LangBtn"))
    langBtn.SetFont("s8 c888888")
    langBtn.OnEvent("Click", ToggleLanguage)

    ; ── Status indicator ──
    appGui.SetFont("s11 w700 cFF3B30")
    txtStatus := appGui.AddText("vStatusText x20 y42 w460 Center +Background1A1A1A", "●  " L("StatusStopped"))

    ; ═══════════════════════════════════════════════
    ; CARD 1 — Execution Interval
    ; ═══════════════════════════════════════════════
    appGui.AddText("x20 y75 w460 h55 +Background1A1A1A")

    appGui.SetFont("s9 w600 cFFFFFF")
    appGui.AddText("vSettingsHeader x35 y83 w200 +Background1A1A1A", "▸  " L("Settings"))
    appGui.SetFont("s8 w400 c888888")
    appGui.AddText("vIntervalLabel x35 y103 w250 +Background1A1A1A", L("Interval"))

    editInt := appGui.AddEdit("vIntervalEdit x400 y85 w65 h22 +Number +Center -Border Background262626 cFFFFFF", "120")
    appGui.SetFont("s8 c555555")
    appGui.AddText("x400 y110 w65 Center +Background1A1A1A", "sec")

    ; ═══════════════════════════════════════════════
    ; CARD 2 — Activity Toggles & Methods (Dynamic y+N Grid)
    ; ═══════════════════════════════════════════════
    appGui.AddText("x20 y145 w460 h240 +Background1A1A1A")

    ; TOGGLE 1: Фоновый режим
    appGui.SetFont("s9 w600 cFFFFFF")
    appGui.AddText("vBgModeLabel x35 y155 w350 +Background1A1A1A", L("BgMode"))
    btnToggleBg := appGui.AddText("vBtnToggleBg x400 y153 w65 h20 +Center +Border +Background262626", "[ OFF ]")
    btnToggleBg.SetFont("s8 w700 c888888")
    btnToggleBg.OnEvent("Click", UI_ToggleBg)

    ; Предупреждение размещено через y+6 (динамический отступ)
    appGui.SetFont("s8 cFF9500")
    appGui.AddText("vBgWarn x35 y+6 w430 +Background1A1A1A", L("BgWarning"))

    ; TOGGLE 2: Только когда Roblox активен (динамический отступ y+14)
    appGui.SetFont("s9 w600 cFFFFFF")
    appGui.AddText("vOnlyActiveLabel x35 y+14 w350 +Background1A1A1A", L("OnlyActive"))
    btnToggleActive := appGui.AddText("vBtnToggleActive x400 yp-2 w65 h20 +Center +Border +Background34C759", "[ ON ]")
    btnToggleActive.SetFont("s8 w700 cFFFFFF")
    btnToggleActive.OnEvent("Click", UI_ToggleActive)

    ; Внутренний разделитель и выбор типа кликера (динамический отступ y+12)
    appGui.AddText("x35 y+12 w430 h1 Background262626")
    appGui.SetFont("s8 c555555")
    appGui.AddText("vActivityLabel x35 y+6 w430 h16 +Background1A1A1A", L("ActivityType"))

    appGui.SetFont("s9 w400 cD0D0D0")
    appGui.AddRadio("vRbMouse x40 y+4 w440 h18 Checked Group +Background1A1A1A", L("MouseMove"))
    appGui.AddRadio("vRbShift x40 y+2 w440 h18 +Background1A1A1A", L("ShiftKey"))
    appGui.AddRadio("vRbScroll x40 y+2 w440 h18 +Background1A1A1A", L("ScrollLock"))

    ; ═══════════════════════════════════════════════
    ; CARD 3 — Auto-Reconnect Module
    ; ═══════════════════════════════════════════════
    appGui.AddText("x20 y400 w460 h65 +Background1A1A1A")

    appGui.SetFont("s9 w600 cFFFFFF")
    appGui.AddText("vReconnectHeader x35 y410 w350 +Background1A1A1A", L("ReconnectCheck"))
    btnToggleRec := appGui.AddText("vBtnToggleRec x400 y407 w65 h20 +Center +Border +Background34C759", "[ ON ]")
    btnToggleRec.SetFont("s8 w700 cFFFFFF")
    btnToggleRec.OnEvent("Click", UI_ToggleRec)

    btnCap := appGui.AddButton("-Theme vCaptureBtn x35 y435 w120 h20", L("CaptureBtn"))
    btnCap.SetFont("s8 cB0B0B0")
    btnCap.OnEvent("Click", ObjBindMethod(ReconnectManager, "CaptureTemplatePrompt"))

    appGui.SetFont("s8 c555555")
    appGui.AddText("vReconnectStatus x165 y438 w310 +Background1A1A1A", L("AutoSearchEnabled"))

    ; ═══════════════════════════════════════════════
    ; MASTER BUTTON PANEL
    ; ═══════════════════════════════════════════════
    appGui.SetFont("s10 w700 cFFFFFF")
    btnMaster := appGui.AddButton("vStartBtn x20 y480 w340 h35", "START WORKER")
    btnMaster.OnEvent("Click", UI_MasterEngine)

    btnSett := appGui.AddButton("vSettingsBtn x370 y480 w110 h35", L("SettingsBtn"))
    btnSett.SetFont("s9 w400 c888888")
    btnSett.OnEvent("Click", (*) => ShowSettingsWindow())

    btnToTray := appGui.AddButton("vTrayBtn x370 y520 w110 h20", L("ToTray"))
    btnToTray.SetFont("s8 w400 c555555")
    btnToTray.OnEvent("Click", HideToTray)

    ; ── Log ──
    appGui.SetFont("s8 w600 c444444")
    appGui.AddText("vLogLabel x25 y552 w450 h14", L("LogLabel"))
    appGui.SetFont("s8 w400 cA0A0A0")
    appGui.AddEdit("vLogEdit x20 y568 w460 h130 ReadOnly Multi WantReturn -Border Background161616 -E0x200")

    appGui.OnEvent("Close", OnClosing)
    appGui.Show("w500 h720 Center")

    SyncToggleVisuals()
}

; ============================================================
;  GUI EVENTS & TRANSLATION REFRESH
; ============================================================
ToggleLanguage(*) {
    global appGui, currentLang
    currentLang := currentLang = "ru" ? "en" : "ru"
    LoadLanguage(currentLang)

    appGui.Title := L("WindowTitle")
    appGui["LangBtn"].Text := L("LangBtn")
    hotkeysText := StrReplace(StrReplace(L("Hotkeys"), "{1}", ConfigManager.HotkeyToggle), "{2}", ConfigManager.HotkeyCapture)
    appGui["HotkeysLabel"].Text := hotkeysText

    appGui["SettingsHeader"].Text := "▸  " L("Settings")
    appGui["IntervalLabel"].Text := L("Interval")
    appGui["BgModeLabel"].Text := L("BgMode")
    appGui["BgWarn"].Text := L("BgWarning")
    appGui["OnlyActiveLabel"].Text := L("OnlyActive")
    appGui["ActivityLabel"].Text := L("ActivityType")
    appGui["RbMouse"].Text := L("MouseMove")
    appGui["RbShift"].Text := L("ShiftKey")
    appGui["RbScroll"].Text := L("ScrollLock")
    appGui["ReconnectHeader"].Text := L("ReconnectCheck")
    appGui["CaptureBtn"].Text := L("CaptureBtn")
    appGui["LogLabel"].Text := L("LogLabel")
    appGui["SettingsBtn"].Text := L("SettingsBtn")
    appGui["TrayBtn"].Text := L("ToTray")

    global isRunningState
    if (isRunningState) {
        appGui["StatusText"].Text := "●  " L("StatusRunning")
        appGui["StartBtn"].Text := L("Stop")
    } else {
        appGui["StatusText"].Text := "●  " L("StatusStopped")
        appGui["StartBtn"].Text := L("Start")
    }

    UpdateReconnectStatus()
}

; =================================================================
;  TOGGLE INTERACTIVE EVENT HANDLERS
; =================================================================
UI_ToggleBg(ctrl, *) {
    global bgState, btnToggleBg, appGui
    bgState := !bgState
    if (bgState) {
        btnToggleBg.Opt("+Background34C759 +cFFFFFF")
        btnToggleBg.Text := "[ ON ]"
        appGui["RbMouse"].Enabled := false
        if (appGui["RbMouse"].Value)
            appGui["RbShift"].Value := 1
    } else {
        btnToggleBg.Opt("+Background262626 +c888888")
        btnToggleBg.Text := "[ OFF ]"
        appGui["RbMouse"].Enabled := true
    }
}

UI_ToggleActive(ctrl, *) {
    global activeState, btnToggleActive
    activeState := !activeState
    if (activeState) {
        btnToggleActive.Opt("+Background34C759 +cFFFFFF")
        btnToggleActive.Text := "[ ON ]"
    } else {
        btnToggleActive.Opt("+Background262626 +c888888")
        btnToggleActive.Text := "[ OFF ]"
    }
}

UI_ToggleRec(ctrl, *) {
    global recState, btnToggleRec
    recState := !recState
    if (recState) {
        btnToggleRec.Opt("+Background34C759 +cFFFFFF")
        btnToggleRec.Text := "[ ON ]"
        ReconnectManager.Start()
    } else {
        btnToggleRec.Opt("+Background262626 +c888888")
        btnToggleRec.Text := "[ OFF ]"
        ReconnectManager.Stop()
    }
}

UI_MasterEngine(ctrl, *) {
    global isRunningState, btnMaster, txtStatus
    isRunningState := !isRunningState
    if (isRunningState) {
        btnMaster.Text := L("Stop")
        txtStatus.Opt("+c34C759")
        txtStatus.Text := "●  " L("StatusRunning")
        AFKEngine.StartFromUI()
    } else {
        btnMaster.Text := L("Start")
        txtStatus.Opt("+cFF3B30")
        txtStatus.Text := "●  " L("StatusStopped")
        AFKEngine.StopFromUI()
    }
}

SyncToggleVisuals() {
    global bgState, activeState, recState, btnToggleBg, btnToggleActive, btnToggleRec, appGui

    if (bgState) {
        btnToggleBg.Opt("+Background34C759 +cFFFFFF")
        btnToggleBg.Text := "[ ON ]"
        appGui["RbMouse"].Enabled := false
    } else {
        btnToggleBg.Opt("+Background262626 +c888888")
        btnToggleBg.Text := "[ OFF ]"
    }

    if (activeState) {
        btnToggleActive.Opt("+Background34C759 +cFFFFFF")
        btnToggleActive.Text := "[ ON ]"
    } else {
        btnToggleActive.Opt("+Background262626 +c888888")
        btnToggleActive.Text := "[ OFF ]"
    }

    if (recState) {
        btnToggleRec.Opt("+Background34C759 +cFFFFFF")
        btnToggleRec.Text := "[ ON ]"
    } else {
        btnToggleRec.Opt("+Background262626 +c888888")
        btnToggleRec.Text := "[ OFF ]"
    }
}

; Backward compatibility layers for external engine calls
OnBgToggle(ctrl, *) {
    global bgState
    bgState := ctrl.HasProp("Value") ? ctrl.Value : bgState
    SyncToggleVisuals()
}

OnReconnectToggle(ctrl, *) {
    global recState
    recState := ctrl.HasProp("Value") ? ctrl.Value : recState
    SyncToggleVisuals()
    if (recState)
        ReconnectManager.Start()
    else
        ReconnectManager.Stop()
}

; ============================================================
;  SETTINGS WINDOW
; ============================================================
ShowSettingsWindow() {
    global appGui
    settingsGui := Gui("+Owner" appGui.Hwnd " +ToolWindow -MinimizeBox", L("SettingsTitle"))
    settingsGui.BackColor := "1A1A1A"
    settingsGui.SetFont("s9 cE0E0E0", "Segoe UI")
    settingsGui.MarginX := 15
    settingsGui.MarginY := 12

    ; Section header
    settingsGui.SetFont("s9 w600 cFFFFFF")
    settingsGui.AddText("x15 y14 w300", "▸  " L("SearchGroup"))
    settingsGui.AddText("x15 y33 w300 h1 Background3A3A3A")

    ; Reconnect interval
    settingsGui.SetFont("s9 w400 cE0E0E0")
    settingsGui.AddText("x15 y44 w200 h22", L("SearchIntervalLabel"))
    settingsGui.AddEdit("vSearchIntervalEdit x220 y41 w80 h22 +Number +Center Background2A2A2A cE0E0E0 -E0x200", ConfigManager.ReconnectInterval)

    ; AFK interval
    settingsGui.AddText("x15 y72 w200 h22", L("AFKIntervalLabel"))
    settingsGui.AddEdit("vAFKIntervalEdit x220 y69 w80 h22 +Number +Center Background2A2A2A cE0E0E0 -E0x200", ConfigManager.AFKInterval)

    ; Checkboxes
    settingsGui.AddText("x15 y100 w300 h1 Background3A3A3A")
    settingsGui.AddCheckBox("vAutoSearchChk x15 y110 w300 h20 Checked" ConfigManager.AutoSearch, L("AutoSearchLabel"))
    settingsGui.AddCheckBox("vRunOnStartupChk x15 y134 w300 h20 Checked" ConfigManager.RunOnStartup, L("RunOnStartupLabel"))

    ; Buttons
    settingsGui.AddText("x15 y162 w300 h1 Background3A3A3A")
    settingsGui.SetFont("s9 w600 cE0E0E0")
    btnSave := settingsGui.AddButton("x15 y172 w140 h30", L("SaveBtn"))
    btnSave.OnEvent("Click", (ctrl, *) => OnSaveSettings(settingsGui))

    btnCancel := settingsGui.AddButton("x165 y172 w140 h30", L("CancelBtn"))
    btnCancel.OnEvent("Click", (*) => settingsGui.Destroy())

    settingsGui.Show("w315 h216 Center")
}

OnSaveSettings(guiObj) {
    saved := guiObj.Submit()

    ConfigManager.ReconnectInterval := Number(saved.SearchIntervalEdit)
    ConfigManager.AFKInterval := Number(saved.AFKIntervalEdit)
    ConfigManager.AutoSearch := saved.AutoSearchChk
    ConfigManager.RunOnStartup := saved.RunOnStartupChk
    ConfigManager.HotkeyToggle := saved.HasProp("HotkeyToggleEdit") && saved.HotkeyToggleEdit != "" ? saved.HotkeyToggleEdit : ConfigManager.HotkeyToggle
    ConfigManager.HotkeyCapture := saved.HasProp("HotkeyCaptureEdit") && saved.HotkeyCaptureEdit != "" ? saved.HotkeyCaptureEdit : ConfigManager.HotkeyCapture
    ConfigManager.Save()
    ConfigManager.UpdateRegistry()

    ReconnectManager.UpdateTimer()
    SetupHotkeys()

    global appGui
    if (IsObject(appGui) && HasProp(appGui, "HotkeysLabel")) {
        hotkeysText := StrReplace(StrReplace(L("Hotkeys"), "{1}", ConfigManager.HotkeyToggle), "{2}", ConfigManager.HotkeyCapture)
        appGui["HotkeysLabel"].Text := hotkeysText
    }

    LogMsg(L("SettingsSaved"))
}

; ============================================================
;  HOTKEYS
; ============================================================
global currentHotkeyToggle := ""
global currentHotkeyCapture := ""

SetupHotkeys() {
    global currentHotkeyToggle, currentHotkeyCapture

    if (currentHotkeyToggle != "")
        try Hotkey(currentHotkeyToggle, "Off")
    if (currentHotkeyCapture != "")
        try Hotkey(currentHotkeyCapture, "Off")

    currentHotkeyToggle := ConfigManager.HotkeyToggle
    currentHotkeyCapture := ConfigManager.HotkeyCapture

    try Hotkey(currentHotkeyToggle, ObjBindMethod(AFKEngine, "Toggle"), "On")
    try Hotkey(currentHotkeyCapture, ObjBindMethod(ReconnectManager, "CaptureTemplate"), "On")
}

; ============================================================
;  ENTRY POINT
; ============================================================
ConfigManager.Load()

; Запуск проверки обновлений в отдельном асинхронном потоке
SetTimer(() => AutoUpdater.CheckForUpdates(APP_VERSION), -100)

if (!CheckActivation()) {
    ; Окно активации запущено, ожидаем ввода пользователя
} else {
    ShowMainWindow()
    SetupTray()
    SetupHotkeys()
}