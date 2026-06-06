#Requires AutoHotkey v2.0
#Include GameMango.ahk
#Include GUI.ahk
#Include OCR-main\Lib\OCR.ahk
; ============================================================
;  Lib\ZombieArenaFarm_AA.ahk
;  Zombie Arena Farm — адаптация под Anime Adventures framework.
;
;  Что использует из AA:
;    • forceRobloxSize() / sizeDown() / moveRobloxWindow()  — из GUI.ahk
;    • Reconnect()                                          — из GameMango.ahk
;    • ProcessLog(msg)                                      — из GUI.ahk
;    • OCR (Lib\OCR-main\Lib\OCR.ahk)                      — уже подключён
;    • rblxID ("ahk_exe RobloxPlayerBeta.exe")             — из GUI.ahk
;
;  Горячие клавиши:
;    F1  — позиционировать окно Roblox (уже в GameMango.ahk)
;    F2  — СТАРТ Zombie Arena Farm
;    F3  — СТОП / Перезагрузка скрипта
;    F4  — Настройки (изменить интервалы прямо в скрипте пока)
; ============================================================

; Silence IDE/LSP warnings for variables defined in other files
if false {
    ZA_Q_En := ZA_Q_Key := ZA_Q_Int := ZA_E_En := ZA_E_Key := ZA_E_Int := ""
    ZA_R_En := ZA_R_Key := ZA_R_Int := ZA_Aim_En := ZA_Aim_Int := ZA_Atk_En := ZA_Atk_Int := ZA_PA_En := ZA_PA_Int := ""
}

; ── Global settings (defaults) ───────────────────────────────
global ZA_AttackEnabled    := true
global ZA_AttackInterval   := 800
global ZA_Key1Enabled      := true
global ZA_Key1             := "q"
global ZA_Key1Interval     := 5000
global ZA_Key2Enabled      := true
global ZA_Key2             := "e"
global ZA_Key2Interval     := 5000
global ZA_Key3Enabled      := false
global ZA_Key3             := "r"
global ZA_Key3Interval     := 5000
global ZA_PlayAgainEnabled := true
global ZA_PlayAgainInterval := 8000
global ZA_ShootEnabled     := true
global ZA_ShootInterval    := 600
global ZA_TargetMap        := "Rooftop Siege"
global ZA_TargetDifficulty := "Normal"

; ── Apply config from UI controls into working globals ───────
global ZA_ApplyConfig := ZA_ApplyConfig_Impl

ZA_ApplyConfig_Impl() {
    global ZA_AttackEnabled, ZA_AttackInterval
    global ZA_Key1Enabled, ZA_Key1, ZA_Key1Interval
    global ZA_Key2Enabled, ZA_Key2, ZA_Key2Interval
    global ZA_Key3Enabled, ZA_Key3, ZA_Key3Interval
    global ZA_ShootEnabled, ZA_ShootInterval
    global ZA_PlayAgainEnabled, ZA_PlayAgainInterval
    global ZA_TargetMap, ZA_TargetDifficulty
    global ZA_Q_En, ZA_Q_Key, ZA_Q_Int
    global ZA_E_En, ZA_E_Key, ZA_E_Int
    global ZA_R_En, ZA_R_Key, ZA_R_Int
    global ZA_Aim_En, ZA_Aim_Int
    global ZA_Atk_En, ZA_Atk_Int
    global ZA_PA_En, ZA_PA_Int
    global ZA_MapDD, ZA_DiffDD

    try {
        ZA_Key1Enabled      := ZA_Q_En.Value  ? true : false
        ZA_Key1             := Trim(ZA_Q_Key.Value)
        ZA_Key1Interval     := Max(100, Integer(ZA_Q_Int.Value))

        ZA_Key2Enabled      := ZA_E_En.Value  ? true : false
        ZA_Key2             := Trim(ZA_E_Key.Value)
        ZA_Key2Interval     := Max(100, Integer(ZA_E_Int.Value))

        ZA_Key3Enabled      := ZA_R_En.Value  ? true : false
        ZA_Key3             := Trim(ZA_R_Key.Value)
        ZA_Key3Interval     := Max(100, Integer(ZA_R_Int.Value))

        ZA_ShootEnabled     := ZA_Aim_En.Value ? true : false
        ZA_ShootInterval    := Max(100, Integer(ZA_Aim_Int.Value))

        ZA_AttackEnabled    := ZA_Atk_En.Value ? true : false
        ZA_AttackInterval   := Max(100, Integer(ZA_Atk_Int.Value))

        ZA_PlayAgainEnabled  := ZA_PA_En.Value  ? true : false
        ZA_PlayAgainInterval := Max(500, Integer(ZA_PA_Int.Value))

        if IsSet(ZA_MapDD) && IsObject(ZA_MapDD)
            ZA_TargetMap := ZA_MapDD.Text
        if IsSet(ZA_DiffDD) && IsObject(ZA_DiffDD)
            ZA_TargetDifficulty := ZA_DiffDD.Text
    } catch as e {
        try ProcessLog("[ZA] ApplyConfig error: " e.Message)
    }
}


; ── Состояние ───────────────────────────────────────────────
global ZA_IsRunning         := false
global ZA_IsWaitingForLoad  := false
global ZA_CombatActive      := false
global ZA_NoTargetTicks     := 0
global ZA_LastEnemyMs       := 0
global ZA_RoundStartMs      := 0

; ── Ссылки на таймеры (для отмены) ─────────────────────────
global ZA_fnAttack     := ""
global ZA_fnKey1       := ""
global ZA_fnKey2       := ""
global ZA_fnPlayAgain  := ""
global ZA_fnKey3       := ""
global ZA_fnAim        := ""


; ============================================================
;  ZA_Start() - Точка входа по F2
; ============================================================
ZA_Start() {
    global ZA_IsRunning, ZA_CombatActive
    
    if ZA_IsRunning {
        try ProcessLog("ZombieArena: already running")
        return
    }

    try ZA_ApplyConfig()
    ZA_IsRunning := true
    ZA_CombatActive := false

    try ProcessLog("🧟 Zombie Arena Hub Cycle STARTED")
    try ProcessLog("F3 = Stop  |  F1 = Reposition window")

    try forceRobloxSize()
    Sleep(300)

    SetTimer(ZA_StartHubCycle, -100)
}

; ============================================================
;  ZA_StartCombatCycle() - Боевой цикл (вызывается после загрузки карты)
; ============================================================
ZA_StartCombatCycle() {
    global ZA_IsRunning, ZA_IsWaitingForLoad, ZA_NoTargetTicks, ZA_LastEnemyMs
    global ZA_fnAttack, ZA_fnKey1, ZA_fnKey2, ZA_fnKey3, ZA_fnPlayAgain, ZA_fnAim
    global ZA_RoundStartMs
    global ZA_CombatActive

    if ZA_CombatActive {
        try ProcessLog("ZombieArena: combat already active")
        return
    }

    ; Принудительно применяем UI (если не было Confirm)
    try ZA_ApplyConfig()

    ZA_IsRunning        := true
    ZA_CombatActive     := true
    ZA_IsWaitingForLoad := false
    ZA_NoTargetTicks    := 0
    ZA_LastEnemyMs      := 0
    ZA_RoundStartMs     := A_TickCount

    try ProcessLog("⚔️ Zombie Arena Combat Cycle STARTED")

    ; Настраиваем камеру
    ZA_SetupCamera()
    Sleep(500)
    ZA_SelectWeapon()

    ; Создаём привязанные функции (один раз)
    if (ZA_fnAttack = "")
        ZA_fnAttack    := ZA_DoAttack.Bind()
    if (ZA_fnKey1 = "")
        ZA_fnKey1      := ZA_DoKey1.Bind()
    if (ZA_fnKey2 = "")
        ZA_fnKey2      := ZA_DoKey2.Bind()
    if (ZA_fnKey3 = "")
        ZA_fnKey3      := ZA_DoKey3.Bind()
    if (ZA_fnPlayAgain = "")
        ZA_fnPlayAgain := ZA_DoPlayAgain.Bind()
    if (ZA_fnAim = "")
        ZA_fnAim       := ZA_DoAimAndShoot.Bind()

    ; Запускаем таймеры
    if ZA_AttackEnabled
        SetTimer(ZA_fnAttack,    -ZA_AttackInterval)
    if (ZA_Key1Enabled && ZA_Key1 != "")
        SetTimer(ZA_fnKey1,      -ZA_Key1Interval)
    if (ZA_Key2Enabled && ZA_Key2 != "")
        SetTimer(ZA_fnKey2,      -ZA_Key2Interval)
    if (ZA_Key3Enabled && ZA_Key3 != "")
        SetTimer(ZA_fnKey3,      -ZA_Key3Interval)
    if ZA_PlayAgainEnabled
        SetTimer(ZA_fnPlayAgain, -ZA_PlayAgainInterval)
    if ZA_ShootEnabled
        SetTimer(ZA_fnAim,       -ZA_ShootInterval)
}

; ============================================================
;  ZA_Stop()
; ============================================================
ZA_Stop() {
    global ZA_IsRunning
    if ZA_IsRunning {
        try ProcessLog("🧟 Zombie Arena Farm STOPPED")
        Sleep(500)
    }
    Reload()
}

; ============================================================
;  ZA_Guard() — Roblox должен быть активным окном
; ============================================================
ZA_Guard() {
    return WinActive("ahk_exe RobloxPlayerBeta.exe")
           || WinActive("Roblox")
}

; ============================================================
;  ZA_GetRobloxWindow()  →  hwnd или 0
; ============================================================
ZA_GetRobloxWindow() {
    if hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
        return hwnd
    if hwnd := WinExist("Roblox ahk_exe ApplicationFrameHost.exe")
        return hwnd
    return 0
}

; ============================================================
;  ZA_SetupCamera()
;  Зум назад + наклон камеры вниз (как в оригинальном модуле).
; ============================================================
ZA_SetupCamera() {
    hwnd := ZA_GetRobloxWindow()
    if !hwnd
        return

    try {
        CoordMode("Mouse", "Screen")
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
        cx := wx + ww // 2
        cy := wy + wh // 2

        if !WinActive("ahk_id " hwnd) {
            WinActivate("ahk_id " hwnd)
            WinWaitActive("ahk_id " hwnd,, 2)
        }
        Sleep(200)

        MouseMove(cx, cy)
        Sleep(120)

        ; Зум назад
        Send("{WheelDown 8}")
        Sleep(350)

        ; Наклон камеры вниз (RMB drag)
        MouseClickDrag("Right", cx, cy, cx, cy + 160, 4)
        Sleep(200)

        try ProcessLog("[ZA] Camera set up (zoom + angle)")
    } catch as e {
        try ProcessLog("[ZA] SetupCamera error: " e.Message)
    }
}

; ============================================================
;  ZA_SelectWeapon()
;  Нажимает {1} для выбора оружия.
; ============================================================
ZA_SelectWeapon() {
    hwnd := ZA_GetRobloxWindow()
    if !hwnd
        return
    try {
        if !WinActive("ahk_id " hwnd) {
            WinActivate("ahk_id " hwnd)
            WinWaitActive("ahk_id " hwnd,, 2)
        }
        Sleep(150)
        SendInput("{1}")
        Sleep(Random(300, 500))
        try ProcessLog("[ZA] Weapon selected (key 1)")
    } catch as e {
        try ProcessLog("[ZA] SelectWeapon error: " e.Message)
    }
}

; ============================================================
;  ZA_DoAttack()  — одиночный ЛКМ-клик по центру экрана
; ============================================================
ZA_DoAttack() {
    global ZA_IsRunning, ZA_IsWaitingForLoad, ZA_fnAttack, ZA_AttackInterval
    global ZA_RoundStartMs

    if (!ZA_IsRunning || ZA_IsWaitingForLoad || A_TickCount - ZA_RoundStartMs > 120000) {
        SetTimer(ZA_fnAttack, -(ZA_AttackInterval + Random(0, 200)))
        return
    }
    if !ZA_Guard() {
        try MouseClick("Left",,, 1,, "U")
        SetTimer(ZA_fnAttack, -(ZA_AttackInterval + Random(0, 200)))
        return
    }

    hwnd := ZA_GetRobloxWindow()
    if hwnd {
        try {
            if WinGetMinMax("ahk_id " hwnd) = -1
                throw Error("Window minimized")

            CoordMode("Mouse", "Screen")
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
            if (!ww || !wh)
                throw Error("Invalid window metrics")

            cx := wx + ww // 2 + Random(-30, 30)
            cy := wy + wh // 2 + Random(-20, 20)

            if ZA_IsWaitingForLoad
                throw Error("Waiting for load")

            MouseMove(cx, cy)
            MouseClick("Left",,, 1,, "D")
            try ProcessLog("[ZA] Attack (LMB)")
        } catch as e {
            if InStr(e.Message, "Waiting for load")
                return
            try ProcessLog("ZA Attack error: " e.Message)
        }
    }

    nextT := Integer(ZA_AttackInterval * (0.8 + Random(0, 40) / 100.0))
    if nextT < 300
        nextT := 300
    SetTimer(ZA_fnAttack, -nextT)
}

; ============================================================
;  ZA_DoKey1()  — первая пользовательская клавиша
; ============================================================
ZA_DoKey1() {
    global ZA_IsRunning, ZA_IsWaitingForLoad, ZA_fnKey1
    global ZA_Key1, ZA_Key1Enabled, ZA_Key1Interval
    global ZA_RoundStartMs

    if (!ZA_IsRunning || ZA_IsWaitingForLoad) {
        SetTimer(ZA_fnKey1, -(ZA_Key1Interval + Random(0, 500)))
        return
    }
    if (!ZA_Key1Enabled || ZA_Key1 = "") {
        SetTimer(ZA_fnKey1, -(ZA_Key1Interval + Random(0, 500)))
        return
    }
    if !ZA_Guard() {
        SetTimer(ZA_fnKey1, -(ZA_Key1Interval + Random(0, 500)))
        return
    }

    try {
        SendInput("{" ZA_Key1 "}")
        try ProcessLog("[ZA] Key 1 pressed [" ZA_Key1 "]")
    } catch as e {
        try ProcessLog("ZA Key1 error: " e.Message)
    }

    nextT := Integer(ZA_Key1Interval * (0.85 + Random(0, 30) / 100.0))
    SetTimer(ZA_fnKey1, -nextT)
}

; ============================================================
;  ZA_DoKey2()  — вторая пользовательская клавиша
; ============================================================
ZA_DoKey2() {
    global ZA_IsRunning, ZA_IsWaitingForLoad, ZA_fnKey2
    global ZA_Key2, ZA_Key2Enabled, ZA_Key2Interval
    global ZA_RoundStartMs

    if (!ZA_IsRunning || ZA_IsWaitingForLoad) {
        SetTimer(ZA_fnKey2, -(ZA_Key2Interval + Random(0, 500)))
        return
    }
    if (!ZA_Key2Enabled || ZA_Key2 = "") {
        SetTimer(ZA_fnKey2, -(ZA_Key2Interval + Random(0, 500)))
        return
    }
    if !ZA_Guard() {
        SetTimer(ZA_fnKey2, -(ZA_Key2Interval + Random(0, 500)))
        return
    }

    try {
        SendInput("{" ZA_Key2 "}")
        try ProcessLog("[ZA] Key 2 pressed [" ZA_Key2 "]")
    } catch as e {
        try ProcessLog("ZA Key2 error: " e.Message)
    }

    nextT := Integer(ZA_Key2Interval * (0.85 + Random(0, 30) / 100.0))
    SetTimer(ZA_fnKey2, -nextT)
}

; ============================================================
;  ZA_DoKey3()  — третья пользовательская клавиша (R)
; ============================================================
ZA_DoKey3() {
    global ZA_IsRunning, ZA_IsWaitingForLoad, ZA_fnKey3
    global ZA_Key3, ZA_Key3Enabled, ZA_Key3Interval
    global ZA_RoundStartMs

    if (!ZA_IsRunning || ZA_IsWaitingForLoad) {
        SetTimer(ZA_fnKey3, -(ZA_Key3Interval + Random(0, 500)))
        return
    }
    if (!ZA_Key3Enabled || ZA_Key3 = "") {
        SetTimer(ZA_fnKey3, -(ZA_Key3Interval + Random(0, 500)))
        return
    }
    if !ZA_Guard() {
        SetTimer(ZA_fnKey3, -(ZA_Key3Interval + Random(0, 500)))
        return
    }

    try {
        SendInput("{" ZA_Key3 "}")
        try ProcessLog("[ZA] Key 3 pressed [" ZA_Key3 "]")
    } catch as e {
        try ProcessLog("ZA Key3 error: " e.Message)
    }

    nextT := Integer(ZA_Key3Interval * (0.85 + Random(0, 30) / 100.0))
    SetTimer(ZA_fnKey3, -nextT)
}

; ============================================================
;  ZA_ScanPlayAgain()
;  OCR-поиск кнопки "Play again". При успехе:
;    1. Блокирует остальные таймеры (_isWaitingForLoad = true)
;    2. Жмёт Escape (снимает курсор-захват Roblox)
;    3. Кликает по кнопке 3 раза
;    4. Ждёт загрузки, настраивает камеру и оружие
;    5. Разблокирует таймеры
; ============================================================
ZA_ScanPlayAgain() {
    global ZA_IsWaitingForLoad, ZA_NoTargetTicks, ZA_LastEnemyMs

    hwnd := ZA_GetRobloxWindow()
    if !hwnd {
        try ProcessLog("[ZA] OCR scan skipped: no Roblox window")
        return false
    }
    if ZA_IsWaitingForLoad {
        return false
    }

    try ProcessLog("[ZA] OCR scan for 'Play again'...")
    try {
        CoordMode("Mouse", "Screen")
        ; Координаты Roblox-окна
        WinGetPos(&rx, &ry, &rw, &rh, "ahk_id " hwnd)
        if (rx = "" || ry = "" || rw = "" || rh = "")
            throw Error("Cannot get Roblox window position")

        ; Сканируем 30%-95% высоты окна (кнопка обычно в центре/ниже центра)
        scanY := ry + Integer(rh * 0.30)
        scanH := Integer(rh * 0.65)

        ; НЕ используем grayscale — зелёный текст на тёмном фоне теряет контраст
        ocrResult := OCR.FromRect(rx, scanY, rw, scanH, "en-US", {scale: 2})

        txt := ocrResult.Text
        try ProcessLog("[ZA] OCR raw: " SubStr(txt, 1, 120))

        ; Ищем любую из ключевых фраз результата раунда или реконнекта
        playFound := InStr(txt, "same team", false) || InStr(txt, "Credits Earned", false) || InStr(txt, "RETURN TO", false)
        reconnectFound := InStr(txt, "Reconnect", false)

        if (!playFound && !reconnectFound)
            throw TargetError("End-of-round screen or Reconnect not detected in OCR")

        if (reconnectFound) {
            found := ""
            try found := ocrResult.FindString("Reconnect")
            if (found != "") {
                clickX := rx + found.x + found.w // 2
                clickY := scanY + found.y + found.h // 2
                
                ZA_IsWaitingForLoad := true
                MouseClick("Left",,, 1,, "U")
                MouseClick("Right",,, 1,, "U")
                Sleep(200)

                if !WinActive("ahk_id " hwnd) {
                    WinActivate("ahk_id " hwnd)
                    WinWaitActive("ahk_id " hwnd,, 2)
                }

                CoordMode("Mouse", "Screen")
                MouseMove(clickX, clickY, 3)
                Sleep(400)
                MouseClick("Left", clickX, clickY, 1, 0, "D")
                Sleep(100)
                MouseClick("Left", clickX, clickY, 1, 0, "U")

                try ProcessLog("[ZA] Clicked Reconnect. Initiating recovery...")
                ZA_RecoverFromDisconnect()
                return true
            }
        }

        ; Ищем слово "team" для клика (оно находится на нужной зелёной кнопке)
        found := ""
        try found := ocrResult.FindString("team")
        if (found = "")
            try found := ocrResult.FindString("same")
        if (found = "")
            throw TargetError("'team' or 'same' word not found for click coords")

        ; FromRect координаты — относительно захваченного прямоугольника
        clickX := rx + found.x + found.w // 2
        clickY := scanY + found.y + found.h // 2

        try ProcessLog("[ZA] 'Play again' found at (" clickX "," clickY ")")

        ; Блокируем атаку и прицел
        ZA_IsWaitingForLoad := true

        ; Отпускаем кнопки мыши
        MouseClick("Left",,, 1,, "U")
        MouseClick("Right",,, 1,, "U")
        Sleep(200)

        ; Активируем Roblox
        if !WinActive("ahk_id " hwnd) {
            WinActivate("ahk_id " hwnd)
            WinWaitActive("ahk_id " hwnd,, 2)
        }
        Sleep(400)

        ; Клик
        MouseMove(clickX, clickY, 3)
        Sleep(400)
        
        ; Надежный Roblox-клик с задержкой (чтобы UI точно зарегистрировал)
        MouseClick("Left", clickX, clickY, 1, 0, "D")
        Sleep(100)
        MouseClick("Left", clickX, clickY, 1, 0, "U")
        
        try ProcessLog("[ZA] Clicked Play Again (reliable single click at 403,440)")

        ; Сброс счётчиков
        ZA_NoTargetTicks := 0
        ZA_LastEnemyMs   := 0

        ; Ждём загрузки нового раунда
        Sleep(Random(3500, 4500))

        ZA_SetupCamera()
        Sleep(500)
        ZA_SelectWeapon()

        ZA_IsWaitingForLoad := false
        global ZA_RoundStartMs := A_TickCount
        return true
    } catch as e {
        try ProcessLog("[ZA] PlayAgain OCR fail: " e.Message)
        ZA_IsWaitingForLoad := false
        return false
    }
}



; ============================================================
;  ZA_DoPlayAgain()  — тик таймера (каждые 5-7 с)
; ============================================================
ZA_DoPlayAgain() {
    global ZA_IsRunning, ZA_IsWaitingForLoad, ZA_fnPlayAgain, ZA_PlayAgainInterval

    if !ZA_IsRunning
        return
    if ZA_IsWaitingForLoad {
        SetTimer(ZA_fnPlayAgain, -Random(5000, 7000))
        return
    }

    ; Проверяем реконнект (из GameMango.ahk)
    try Reconnect()

    ZA_ScanPlayAgain()

    if ZA_IsRunning
        SetTimer(ZA_fnPlayAgain, -Random(5000, 7000))
}

; ============================================================
;  ZA_DoAimAndShoot()
;  PixelSearch по зелёному телу зомби (0x6DB83C / 0x86C849).
;  При обнаружении — двигает мышь и удерживает ЛКМ.
; ============================================================
ZA_DoAimAndShoot() {
    global ZA_IsRunning, ZA_IsWaitingForLoad, ZA_fnAim, ZA_ShootInterval
    global ZA_NoTargetTicks, ZA_LastEnemyMs
    global ZA_RoundStartMs

    if (!ZA_IsRunning || ZA_IsWaitingForLoad || A_TickCount - ZA_RoundStartMs > 120000) {
        goto Reschedule
    }
    if !ZA_Guard() {
        try MouseClick("Left",,, 1,, "U")
        goto Reschedule
    }

    hwnd := ZA_GetRobloxWindow()
    if !hwnd
        goto Reschedule

    try {
        if WinGetMinMax("ahk_id " hwnd) = -1
            throw Error("Window minimized")

        CoordMode("Mouse", "Screen")
        CoordMode("Pixel", "Screen")

        wx := 0, wy := 0, ww := 0, wh := 0
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
        ; Guard against empty strings from WinGetPos (window state change race)
        if (wx = "" || wy = "" || ww = "" || wh = "")
            throw Error("WinGetPos returned empty values")
        if (!ww || !wh)
            throw Error("Invalid window metrics")


        ; Зона поиска: нижние 55% окна (камера смотрит вниз)
        searchLeft   := wx + Integer(ww * 0.15)
        searchRight  := wx + Integer(ww * 0.85)
        searchTop    := wy + Integer(wh * 0.35)
        searchBottom := wy + Integer(wh * 0.90)

        found  := false
        foundX := 0
        foundY := 0

        ; Primary: ярко-зелёное тело зомби
        found := PixelSearch(&foundX, &foundY, searchLeft, searchTop, searchRight, searchBottom, 0x6DB83C, 40)
        
        ; Fallback: светло-зелёный вариант
        if !found {
            found := PixelSearch(&foundX, &foundY, searchLeft, searchTop, searchRight, searchBottom, 0x86C849, 35)
        }

        ; Исключаем UI-кнопки (Play again тоже зелёная!). Если нашли зелёный пиксель внизу по центру — игнорируем.
        if found {
            relX := foundX - wx
            relY := foundY - wy
            ; Мёртвая зона: центр экрана по горизонтали (30%-70%) и нижняя часть по вертикали (от 60% и ниже)
            if (relX > ww * 0.30 && relX < ww * 0.70 && relY > wh * 0.60) {
                found := false
            }
        }

        if found {
            if ZA_IsWaitingForLoad {
                try MouseClick("Left",,, 1,, "U")
                goto Reschedule
            }
            aimX := foundX
            aimY := foundY + 15

            MouseMove(aimX, aimY, 3)
            Sleep(60)
            MouseClick("Left",,, 1,, "D")

            ZA_LastEnemyMs   := A_TickCount
            ZA_NoTargetTicks := 0
            try ProcessLog("[ZA] Enemy found, shot fired (" aimX "," aimY ")")
        } else {
            try MouseClick("Left",,, 1,, "U")
            ZA_NoTargetTicks += 1
            try ProcessLog("[ZA] No enemy found [" ZA_NoTargetTicks "/5]")

            ; После 5 пропусков подряд (~3с) — ищем Play Again
            if ZA_NoTargetTicks >= 5 {
                ZA_NoTargetTicks := 0
                ZA_ScanPlayAgain()
            }
        }
    } catch as e {
        try ProcessLog("ZA AimShoot error [L" e.Line "]: " e.Message)
    }

    Reschedule:
    nextT := Integer(ZA_ShootInterval * (0.85 + Random(0, 30) / 100.0))
    SetTimer(ZA_fnAim, -nextT)
}

; ============================================================
; HUB LOGIC & RECOVERY
; ============================================================

ZA_StartHubCycle() {
    global ZA_IsRunning
    if !ZA_IsRunning
        return

    hwnd := ZA_GetRobloxWindow()
    if !hwnd {
        SetTimer(ZA_StartHubCycle, -2000)
        return
    }

    WinActivate("ahk_id " hwnd)
    WinWaitActive("ahk_id " hwnd,, 2)
    Sleep(500)

    try ProcessLog("[ZA] Waiting for 'Play' button in Hub...")
    if ZA_Hub_ClickPlay() {
        try ProcessLog("[ZA] Play button clicked. Waiting for teleport to lobby area...")
        Sleep(4000)
        ZA_Hub_WalkToSpaceship()
        ZA_Hub_CreateMatch()
    } else {
        SetTimer(ZA_StartHubCycle, -3000)
    }
}

ZA_Hub_ClickPlay() {
    hwnd := ZA_GetRobloxWindow()
    if !hwnd
        return false

    WinGetClientPos(,, &cw, &ch, "ahk_id " hwnd)
    scanH := Integer(ch * 0.4)
    
    try {
        ; Use OCR.FromWindow with onlyClientArea=1 to capture the Roblox window directly
        ; This ignores the AHK UI that sits AlwaysOnTop
        result := OCR.FromWindow("ahk_id " hwnd, "en-US", {scale: 2.5}, 1)
        allText := ""
        
        clickX := -1
        clickY := -1
        
        for word in result.Words {
            text := StrReplace(word.Text, " ", "")
            allText .= text " "
            
            if InStr(text, "Reconnect") {
                rX := word.x + word.w // 2
                rY := word.y + word.h // 2
                CoordMode("Mouse", "Client")
                MouseMove(rX, rY, 3)
                Sleep(200)
                MouseClick("Left", rX, rY, 1, 0, "D")
                Sleep(100)
                MouseClick("Left", rX, rY, 1, 0, "U")
                ZA_RecoverFromDisconnect()
                return false
            }
            
            if InStr(text, "Play") || InStr(text, "Pla") || InStr(text, "lay") {
                clickX := word.x + word.w // 2
                clickY := word.y + word.h // 2
                break
            } else if InStr(text, "Loadout") || InStr(text, "rades") {
                ; The Play button is exactly horizontally centered between Loadout and Upgrades.
                ; If OCR fails to read Play due to its color, we use Loadout/Upgrades as a Y-anchor!
                clickX := cw // 2
                clickY := word.y + word.h // 2
                ; Don't break here just in case we find an actual "Play" match later
            }
        }
        
        if (clickX != -1 && clickY != -1 && clickY <= scanH) {
            CoordMode("Mouse", "Client")
            MouseMove(clickX, clickY, 3)
            Sleep(200)
            MouseClick("Left", clickX, clickY, 1, 0, "D")
            Sleep(100)
            MouseClick("Left", clickX, clickY, 1, 0, "U")
            return true
        }
        
        try ProcessLog("[ZA] Play btn not found. Saw: " SubStr(allText, 1, 80))
    }
    return false
}

ZA_Hub_WalkToSpaceship() {
    hwnd := ZA_GetRobloxWindow()
    if !hwnd
        return

    try ProcessLog("[ZA] Scanning for 0/4 lobby...")
    WinGetPos(&rx, &ry, &rw, &rh, "ahk_id " hwnd)

    loop {
        global ZA_IsRunning
        if !ZA_IsRunning
            return

        foundX := -1
        try {
            result := OCR.FromRect(rx, ry, rw, rh, "en-US", {scale: 2})
            for word in result.Words {
                if (InStr(word.Text, "0/4")) {
                    foundX := word.x
                    break
                }
            }
        }
        
        if (foundX != -1) {
            try ProcessLog("[ZA] Found 0/4 lobby at X=" foundX ". Window width=" rw)
            if (foundX < rw / 2) {
                try ProcessLog("[ZA] Lobby is on the LEFT. Walking W+A...")
                SendInput("{w down}{a down}")
                Sleep(3000)
                SendInput("{w up}{a up}")
            } else {
                try ProcessLog("[ZA] Lobby is on the RIGHT. Walking W+D...")
                SendInput("{w down}{d down}")
                Sleep(3000)
                SendInput("{w up}{d up}")
            }
            break
        }
        Sleep(1000)
    }
}

ZA_Hub_CreateMatch() {
    global ZA_TargetMap, ZA_TargetDifficulty
    try ProcessLog("[ZA] Inside lobby. Setting up match...")
    Sleep(2000)

    hwnd := ZA_GetRobloxWindow()
    if !hwnd
        return
    WinActivate("ahk_id " hwnd)
    
    ClickText(targetText, justCheck := false, restrictLeft := false, restrictRight := false) {
        return ZA_Hub_ClickTextInClient(hwnd, targetText, restrictLeft, restrictRight, justCheck)
    }

    if (ZA_TargetMap != "") {
        try ProcessLog("[ZA] Target Map: " ZA_TargetMap)
        ; Always click the map in the left menu
        ClickText(ZA_TargetMap, false, true, false)
    }
    Sleep(1000)

    if (ZA_TargetDifficulty != "") {
        try ProcessLog("[ZA] Target Difficulty: " ZA_TargetDifficulty)
        ; Click whatever difficulty is currently showing on the right to open the dropdown
        if ClickText("Normal", false, false, true) || ClickText("Hardcore", false, false, true) || ClickText("Nightmare", false, false, true) {
            Sleep(1000)
            ; Click the target difficulty in the dropdown
            ClickText(ZA_TargetDifficulty, false, false, true)
        }
    }
    Sleep(1000)

    ClickText("1", false)
    Sleep(500)

    try ProcessLog("[ZA] Clicking CREATE...")
    if ClickText("CREATE", false) {
        Sleep(2000)
        SetTimer(ZA_WaitNextWave, -100)
    } else {
        try ProcessLog("[ZA] Error: CREATE button not found.")
    }
}

ZA_Hub_ClickTextInClient(hwnd, targetText, restrictLeft := false, restrictRight := false, justCheck := false) {
    if !hwnd
        return false

    WinGetClientPos(,, &cw, &ch, "ahk_id " hwnd)
    
    try {
        ; Capture Roblox client area directly
        result := OCR.FromWindow("ahk_id " hwnd, "en-US", {scale: 2.5}, 1)
        
        wordCompare := (w, n) => (StrLen(n) <= 2) ? (w = n) : InStr(w, n)
        matches := result.FindStrings(targetText, false, wordCompare)
        
        for match in matches {
            clickX := match.x + match.w // 2
            clickY := match.y + match.h // 2
            
            if restrictLeft && (clickX >= cw // 2)
                continue
            if restrictRight && (clickX < cw // 2)
                continue
                
            if justCheck
                return true
                
            CoordMode("Mouse", "Client")
            MouseMove(clickX, clickY, 3)
            Sleep(200)
            MouseClick("Left", clickX, clickY, 1, 0, "D")
            Sleep(100)
            MouseClick("Left", clickX, clickY, 1, 0, "U")
            return true
        }
    }
    return false
}

ZA_WaitNextWave() {
    global ZA_IsRunning
    try ProcessLog("[ZA] Waiting for map load (next wave)...")
    hwnd := ZA_GetRobloxWindow()
    if !hwnd
        return

    WinGetPos(&rx, &ry, &rw, &rh, "ahk_id " hwnd)
    loop {
        if !ZA_IsRunning
            return
        
        try {
            result := OCR.FromRect(rx, ry, rw, rh, "en-US", {scale: 2})
            for word in result.Words {
                if InStr(StrLower(word.Text), "wave") {
                    try ProcessLog("[ZA] 'wave' text detected! Starting combat.")
                    ZA_StartCombatCycle()
                    return
                }
            }
        }
        Sleep(2000)
    }
}

ZA_RecoverFromDisconnect() {
    global ZA_IsRunning, ZA_CombatActive
    if !ZA_IsRunning
        return
    ZA_CombatActive := false
    try ProcessLog("[ZA] Reconnecting... Waiting 15 seconds for hub to load.")
    Sleep(15000)
    SetTimer(ZA_StartHubCycle, -100)
}

; ============================================================
;  ProcessLog() — если GUI.ahk не подключён, пишем в лог-файл
; ============================================================
ZA_Log(msg) {
    ; ProcessLog() приходит из GUI.ahk (Anime Adventures)
    ; Эта функция — запасной вариант если GUI недоступен
    try ProcessLog(msg)
    catch
        FileAppend("[" FormatTime(, "HH:mm:ss") "] " msg "`n",
                   A_ScriptDir "\Logs\ZombieArena.log", "UTF-8")
}
