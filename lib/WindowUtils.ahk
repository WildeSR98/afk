; ============================================================
;  lib\WindowUtils.ahk
;  Roblox window detection
; ============================================================

FindRobloxWindow() {
    hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
    if (hwnd)
        return hwnd
    hwnd := WinExist("ahk_class RobloxPlayerBeta")
    if (hwnd)
        return hwnd
    hwnd := WinExist("Roblox ahk_exe RobloxPlayerBeta.exe")
    if (hwnd)
        return hwnd
    hwnd := WinExist("ahk_exe RobloxPlayerBeta")
    return hwnd
}

GetRobloxRect() {
    hwnd := FindRobloxWindow()
    if (!hwnd)
        return 0
    rect := Buffer(16)
    if (!DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect))
        return 0
    left   := NumGet(rect, 0, "Int")
    top    := NumGet(rect, 4, "Int")
    right  := NumGet(rect, 8, "Int")
    bottom := NumGet(rect, 12, "Int")
    if (right <= left || bottom <= top)
        return 0
    return {left: left, top: top, right: right, bottom: bottom}
}

IsRobloxActive() {
    return WinActive("ahk_id " FindRobloxWindow())
}
