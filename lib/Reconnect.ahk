#Requires AutoHotkey v2.0
; ============================================================
;  lib\Reconnect.ahk
;  Auto-reconnect via OCR/Template/Color (OOP Refactored)
; ============================================================

class ReconnectManager {
    static IsRunning    := false
    static RobloxHwnd  := 0
    static LastPos     := 0        ; {X, Y} последняя найденная позиция кнопки
    static LastPosTime := 0        ; A_TickCount момента кеширования
    static CACHE_TTL   := 60000   ; мс — сколько кеш считается валидным

    static ColorDistance(c1, c2) {
        r1 := (c1 >> 16) & 0xFF, g1 := (c1 >> 8) & 0xFF, b1 := c1 & 0xFF
        r2 := (c2 >> 16) & 0xFF, g2 := (c2 >> 8) & 0xFF, b2 := c2 & 0xFF
        return Abs(r1 - r2) + Abs(g1 - g2) + Abs(b1 - b2)
    }

    static CaptureTemplatePrompt(*) {
        LogMsg("Hover over the Reconnect button center and press " ConfigManager.HotkeyCapture "...")
    }

    static CaptureTemplate(*) {
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

    static FindReconnectByTemplate() {
        global TEMPLATE_PNG
        if (!FileExist(TEMPLATE_PNG))
            return 0
        r := GetRobloxRect()
        if (!IsObject(r))
            return 0
        try {
            found := ImageSearch(&fx, &fy, r.left, r.top, r.right, r.bottom, "*75 " TEMPLATE_PNG)
            if (found)
                return {X: r.left + fx, Y: r.top + fy}
        } catch as e {
            LogMsg("ImageSearch error: " e.Message)
        }
        return 0
    }

    static FindReconnectByColor() {
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
                if (this.ColorDistance(col, c) < 80) {
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
                if (this.ColorDistance(col, c) < 80) {
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
            if (this.ColorDistance(centerCol, c) < 100) {
                return {X: cx, Y: cy}
            }
        }
        return 0
    }

    static FindReconnectByOCR() {
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
            br := found.BoundingRect
            relX := br.X - rx
            relY := br.Y - ry
            if (relX < rw * 0.10 || relX > rw * 0.90)
                return 0
            if (relY < rh * 0.10 || relY > rh * 0.95)
                return 0
            cx := br.X + br.W // 2
            cy := br.Y + br.H // 2
            return {X: cx, Y: cy}
        }
        return 0
    }

    ; Быстрая проверка кешированной позиции (±60px)
    static TryLastPos() {
        if (!IsObject(this.LastPos))
            return 0
        if (A_TickCount - this.LastPosTime > this.CACHE_TTL) {
            this.LastPos := 0   ; кеш устарел
            return 0
        }
        cx := this.LastPos.X
        cy := this.LastPos.Y
        r  := GetRobloxRect()
        if (!IsObject(r))
            return 0
        left   := Max(cx - 60, r.left)
        top    := Max(cy - 60, r.top)
        right  := Min(cx + 60, r.right)
        bottom := Min(cy + 60, r.bottom)
        ; Ищем характерный зелёный/синий пиксель вблизи последней позиции
        reconnectColors := [0x00B06A, 0x1E90FF, 0x00A852, 0x0084FF]
        for c in reconnectColors {
            try {
                found := PixelSearch(&fx, &fy, left, top, right, bottom, c, 40)
                if (found)
                    return {X: fx, Y: fy}
            } catch {
                continue
            }
        }
        ; Кеш не подтверждён — инвалидируем
        this.LastPos := 0
        return 0
    }

    static FindReconnectButton() {
        CoordMode("Pixel", "Screen")

        pos := this.FindReconnectByOCR()
        if (IsObject(pos)) {
            LogMsg("Found by OCR: " pos.X "," pos.Y)
            return pos
        }

        pos := this.FindReconnectByTemplate()
        if (IsObject(pos)) {
            LogMsg("Found by template: " pos.X "," pos.Y)
            return pos
        }

        pos := this.FindReconnectByColor()
        if (IsObject(pos)) {
            LogMsg("Found by color: " pos.X "," pos.Y)
            return pos
        }

        return 0
    }

    static DoReconnectClick(x, y) {
        if (!this.RobloxHwnd || !DllCall("IsWindow", "Ptr", this.RobloxHwnd))
            return
        try {
            WinGetPos(&wx, &wy,,, "ahk_id " this.RobloxHwnd)
            
            randX := x + Random(-10, 10)
            randY := y + Random(-10, 10)
            
            relX := randX - wx
            relY := randY - wy
            ControlClick("x" relX " y" relY, "ahk_id " this.RobloxHwnd,, "Left", 1)
            Sleep(Random(80, 200))
        } catch as e {
            LogMsg("ControlClick error: " e.Message)
        }
    }

    static Start() {
        if (this.IsRunning)
            return
        this.RobloxHwnd := FindRobloxWindow()
        if (!this.RobloxHwnd) {
            LogMsg(L("RobloxNotFound"))
            return
        }
        this.IsRunning := true
        LogMsg(L("ReconnectStarted"))
        SetTimer(ObjBindMethod(this, "Tick"), ConfigManager.ReconnectInterval)
    }

    static Stop() {
        this.IsRunning := false
        SetTimer(ObjBindMethod(this, "Tick"), 0)
        LogMsg(L("ReconnectStopped"))
    }

    static Tick() {
        if (!this.IsRunning)
            return
        if (!DllCall("IsWindow", "Ptr", this.RobloxHwnd)) {
            LogMsg("Roblox window closed, reconnect stopped")
            this.Stop()
            return
        }

        ; Сначала проверяем кеш — быстро, без полного сканирования
        pos := this.TryLastPos()
        if (!IsObject(pos)) {
            ; Кеш промахнулся — полное сканирование (OCR + шаблон + цвет)
            pos := this.FindReconnectButton()
        }

        if (IsObject(pos)) {
            ; Обновляем кеш
            this.LastPos := pos
            this.LastPosTime := A_TickCount
            LogMsg(L("ReconnectFound") " " pos.X "," pos.Y)
            this.DoReconnectClick(pos.X, pos.Y)
            TrayTip(L("ReconnectFound"), "Roblox AFK Keeper", "Iconi")
            Sleep(3000)
        }
    }

    static UpdateTimer() {
        if (this.IsRunning) {
            SetTimer(ObjBindMethod(this, "Tick"), 0)
            SetTimer(ObjBindMethod(this, "Tick"), ConfigManager.ReconnectInterval)
            LogMsg("Reconnect interval updated: " ConfigManager.ReconnectInterval " ms")
        }
    }
}
