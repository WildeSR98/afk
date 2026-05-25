; ============================================================
;  lib\Reconnect.ahk
;  Auto-reconnect via OCR (Windows.Media.Ocr)
; ============================================================

ColorDistance(c1, c2) {
    r1 := (c1 >> 16) & 0xFF, g1 := (c1 >> 8) & 0xFF, b1 := c1 & 0xFF
    r2 := (c2 >> 16) & 0xFF, g2 := (c2 >> 8) & 0xFF, b2 := c2 & 0xFF
    return Abs(r1 - r2) + Abs(g1 - g2) + Abs(b1 - b2)
}

CaptureTemplatePrompt(*) {
    LogMsg("Hover over the Reconnect button center and press F8...")
}

CaptureTemplate(*) {
    global TEMPLATE_PNG
    CoordMode("Mouse", "Screen")
    MouseGetPos(&cx, &cy)
    w := 140, h := 50
    left := cx - w//2, top := cy - h//2
    if (left < 0)
        left := 0
    if (top < 0)
        top := 0
    hBmp := Gdip_ScreenCapture(left, top, w, h)
    Gdip_SaveHBITMAPToFile(hBmp, TEMPLATE_PNG)
    LogMsg("Template saved: " TEMPLATE_PNG)
    UpdateReconnectStatus()
}

FindReconnectByTemplate() {
    global TEMPLATE_PNG
    if (!FileExist(TEMPLATE_PNG))
        return 0
    r := GetRobloxRect()
    if (!IsObject(r))
        return 0
    found := ImageSearch(&fx, &fy, r.left, r.top, r.right, r.bottom, "*75 " TEMPLATE_PNG)
    if (found)
        return {X: r.left + fx, Y: r.top + fy}
    return 0
}

FindReconnectByColor() {
    CoordMode("Pixel", "Screen")
    r := GetRobloxRect()
    if (!IsObject(r))
        return 0

    sLeft   := r.left + 50
    sTop    := r.top + 50
    sRight  := r.right - 50
    sBottom := r.bottom - 50
    if (sLeft >= sRight || sTop >= sBottom)
        return 0

    colors := [0x00B06F, 0x00A86B, 0x00C27A, 0x009A60,
               0x3C78D8, 0x2E5CAA, 0x4A90E2, 0x5BA0F2,
               0x1A73E8, 0x4285F4]

    for c in colors {
        found1 := PixelSearch(&x1, &y1, sLeft, sTop, sRight, sBottom, c, 30)
        if (!found1)
            continue

        foundRight := false
        Loop 12 {
            checkX := x1 + 60 + (A_Index * 10)
            if (checkX > sRight)
                break
            col := PixelGetColor(checkX, y1)
            if (ColorDistance(col, c) < 80) {
                foundRight := true
                break
            }
        }
        if (!foundRight)
            continue

        foundBottom := false
        Loop 6 {
            checkY := y1 + 20 + (A_Index * 6)
            if (checkY > sBottom)
                break
            col := PixelGetColor(x1 + 60, checkY)
            if (ColorDistance(col, c) < 80) {
                foundBottom := true
                break
            }
        }
        if (!foundBottom)
            continue

        cx := x1 + 70
        cy := y1 + 22
        if (cx > sRight || cy > sBottom)
            continue
        centerCol := PixelGetColor(cx, cy)
        if (ColorDistance(centerCol, c) < 100) {
            return {X: cx, Y: cy}
        }
    }
    return 0
}

FindReconnectByOCR() {
    CoordMode("Pixel", "Screen")
    hwnd := FindRobloxWindow()
    if (!hwnd)
        return 0

    rx := 0, ry := 0, rw := 0, rh := 0
    try {
        WinGetPos(&rx, &ry, &rw, &rh, "ahk_id " hwnd)
    } catch {
        return 0
    }

    ocrResult := 0
    try {
        ocrResult := OCR.FromWindow("ahk_id " hwnd, {lang: "en-US", scale: 1.5})
    } catch as e1 {
        try {
            ocrResult := OCR.FromWindow("ahk_id " hwnd, {scale: 1.5})
        } catch as e2 {
            LogMsg("OCR error: " e2.Message)
            return 0
        }
    }
    if (!ocrResult)
        return 0

    found := 0
    try {
        found := ocrResult.FindString("Reconnect", {CaseSense: false})
    } catch {
        return 0
    }

    if (found) {
        relX := found.x - rx
        relY := found.y - ry
        if (relX < rw * 0.10 || relX > rw * 0.90)
            return 0
        if (relY < rh * 0.10 || relY > rh * 0.95)
            return 0
        cx := found.x + found.w // 2
        cy := found.y + found.h // 2
        return {X: cx, Y: cy}
    }
    return 0
}

FindReconnectButton() {
    CoordMode("Pixel", "Screen")

    pos := FindReconnectByOCR()
    if (IsObject(pos)) {
        LogMsg("Found by OCR: " pos.X "," pos.Y)
        return pos
    }

    pos := FindReconnectByTemplate()
    if (IsObject(pos)) {
        LogMsg("Found by template: " pos.X "," pos.Y)
        return pos
    }

    pos := FindReconnectByColor()
    if (IsObject(pos)) {
        LogMsg("Found by color: " pos.X "," pos.Y)
        return pos
    }

    return 0
}

DoReconnectClick(x, y) {
    global robloxHwnd
    CoordMode("Mouse", "Screen")
    MouseGetPos(&oldX, &oldY)
    if (!robloxHwnd || !DllCall("IsWindow", "Ptr", robloxHwnd))
        return
    fgHwnd := WinExist("A")
    myThread := DllCall("GetCurrentThreadId")
    fgThread := DllCall("GetWindowThreadProcessId", "Ptr", fgHwnd, "Ptr", 0)

    DllCall("AttachThreadInput", "UInt", myThread, "UInt", fgThread, "Int", 1)
    WinActivate("ahk_id " robloxHwnd)
    WinWaitActive("ahk_id " robloxHwnd, , 0.5)
    MouseMove(x, y, 0)
    Click()
    Sleep(100)
    WinActivate("ahk_id " fgHwnd)
    DllCall("AttachThreadInput", "UInt", myThread, "UInt", fgThread, "Int", 0)
    MouseMove(oldX, oldY, 0)
}

StartReconnect() {
    global reconnectRunning, robloxHwnd
    if (reconnectRunning)
        return
    robloxHwnd := FindRobloxWindow()
    if (!robloxHwnd) {
        LogMsg(L("RobloxNotFound"))
        return
    }
    reconnectRunning := true
    LogMsg(L("ReconnectStarted"))
    SetTimer(ReconnectTick, 5000)
}

StopReconnect() {
    global reconnectRunning
    reconnectRunning := false
    SetTimer(ReconnectTick, 0)
    LogMsg(L("ReconnectStopped"))
}

ReconnectTick() {
    global reconnectRunning, robloxHwnd
    if (!reconnectRunning)
        return
    if (!DllCall("IsWindow", "Ptr", robloxHwnd)) {
        LogMsg("Roblox window closed, reconnect stopped")
        StopReconnect()
        return
    }
    pos := FindReconnectButton()
    if (IsObject(pos)) {
        LogMsg(L("ReconnectFound") " " pos.X "," pos.Y)
        DoReconnectClick(pos.X, pos.Y)
        Sleep(3000)
    }
}
