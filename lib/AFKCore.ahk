; ============================================================
;  lib\AFKCore.ahk
;  AFK Keeper logic (keyboard/mouse simulation)
; ============================================================

StartAFK(*) {
    global afkRunning, appGui
    if (afkRunning)
        return
    afkRunning := true
    appGui["StartBtn"].Enabled := false
    appGui["StopBtn"].Enabled := true
    appGui["StatusText"].Text := L("StatusRunning")
    appGui["StatusText"].Opt("+c00AA00")
    LogMsg(L("AFKStarted"))

    interval := Integer(appGui["IntervalEdit"].Value)
    if (interval < 1)
        interval := 120
    SetTimer(AFKTick, interval * 1000)
}

StopAFK(*) {
    global afkRunning, appGui
    afkRunning := false
    SetTimer(AFKTick, 0)
    appGui["StartBtn"].Enabled := true
    appGui["StopBtn"].Enabled := false
    appGui["StatusText"].Text := L("StatusStopped")
    appGui["StatusText"].Opt("+cFF0000")
    LogMsg(L("AFKStopped"))
}

ToggleAFK(*) {
    global afkRunning
    if (afkRunning)
        StopAFK()
    else
        StartAFK()
}

AFKTick() {
    global afkRunning, appGui
    if (!afkRunning)
        return

    bgMode := appGui["BgCheck"].Value
    onlyActive := appGui["ActiveCheck"].Value

    if (!bgMode && onlyActive) {
        if (!IsRobloxActive()) {
            LogMsg(L("RobloxNotActive"))
            return
        }
    }

    action := "mouse"
    if (appGui["RbShift"].Value)
        action := "shift"
    else if (appGui["RbScroll"].Value)
        action := "scroll"

    if (bgMode) {
        QuickFocusAction(action)
    } else {
        if (action = "mouse") {
            MouseMove(1, 0, 1, "R")
            Sleep(50)
            MouseMove(-1, 0, 1, "R")
            LogMsg(L("InputMouse"))
        } else if (action = "shift") {
            SendInput("{Shift}")
            LogMsg("Input: Shift")
        } else {
            SendInput("{ScrollLock}")
            LogMsg("Input: ScrollLock")
        }
    }
}

QuickFocusAction(action) {
    robloxHwnd := FindRobloxWindow()
    if (!robloxHwnd) {
        LogMsg(L("RobloxNotFound"))
        return false
    }
    if (WinActive("ahk_id " robloxHwnd)) {
        if (action = "shift")
            SendInput("{Shift}")
        else if (action = "scroll")
            SendInput("{ScrollLock}")
        return true
    }
    fgHwnd := WinExist("A")
    myThread := DllCall("GetCurrentThreadId")
    fgThread := DllCall("GetWindowThreadProcessId", "Ptr", fgHwnd, "Ptr", 0)

    DllCall("AttachThreadInput", "UInt", myThread, "UInt", fgThread, "Int", 1)
    WinActivate("ahk_id " robloxHwnd)
    WinWaitActive("ahk_id " robloxHwnd, , 0.5)

    if (action = "shift")
        SendInput("{Shift}")
    else if (action = "scroll")
        SendInput("{ScrollLock}")

    Sleep(50)
    WinActivate("ahk_id " fgHwnd)
    DllCall("AttachThreadInput", "UInt", myThread, "UInt", fgThread, "Int", 0)
    LogMsg(action = "shift" ? L("InputShift") : L("InputScroll"))
    return true
}
