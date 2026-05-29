#Requires AutoHotkey v2.0
; ============================================================
;  lib\AFKCore.ahk
;  AFK Keeper logic — Anti-AFK engine with fuzzy timers
;  v3.3 — OOP Refactored, ControlSend background mode
; ============================================================

class AFKEngine {
    ; Флаг активности AFK-таймера
    static IsRunning := false

    ; ----------------------------------------------------------
    ; SetRandomTimer()
    ;   Планирует следующий тик через случайный интервал ±30%
    ;   от ConfigManager.AFKInterval (в секундах).
    ;   Использует однократный таймер (-RandomTime) для Fuzzy Anti-AFK —
    ;   постоянный интервал легко детектируется поведенческим анализом.
    ; ----------------------------------------------------------
    static SetRandomTimer() {
        if (!this.IsRunning)
            return
        baseInterval := ConfigManager.AFKInterval * 1000
        minTime := Integer(baseInterval * 0.7)
        maxTime := Integer(baseInterval * 1.3)
        if (minTime < 1000)
            minTime := 1000
        RandomTime := Random(minTime, maxTime)
        SetTimer(ObjBindMethod(this, "Tick"), -RandomTime)
    }

    ; ----------------------------------------------------------
    ; StartFromUI() / StopFromUI()
    ;   Вызываются из UI_MasterEngine — только запускают/останавливают таймер.
    ;   GUI-обновление происходит в вызывающей функции.
    ; ----------------------------------------------------------
    static StartFromUI() {
        if (this.IsRunning)
            return
        this.IsRunning := true
        LogMsg(L("AFKStarted"))
        this.SetRandomTimer()
    }

    static StopFromUI() {
        this.IsRunning := false
        SetTimer(ObjBindMethod(this, "Tick"), 0)
        LogMsg(L("AFKStopped"))
    }

    ; ----------------------------------------------------------
    ; Start() / Stop() / Toggle()
    ;   Вызываются из хоткея F10 — триггерят UI_MasterEngine если GUI активен.
    ; ----------------------------------------------------------
    static Start(*) {
        global isRunningState, btnMaster, txtStatus
        if (this.IsRunning)
            return
        ; Если есть GUI — делегируем в UI_MasterEngine чтобы синхронизировать визуал
        if (IsObject(btnMaster) && !isRunningState) {
            isRunningState := 1
            btnMaster.SetFont("cFFFFFF")
            btnMaster.Text := L("Stop")
            txtStatus.Opt("+c34C759")
            txtStatus.Text := L("StatusRunning")
        }
        this.StartFromUI()
    }

    static Stop(*) {
        global isRunningState, btnMaster, txtStatus
        if (!this.IsRunning)
            return
        if (IsObject(btnMaster) && isRunningState) {
            isRunningState := 0
            btnMaster.SetFont("cE0E0E0")
            btnMaster.Text := L("Start")
            txtStatus.Opt("+cFF3B30")
            txtStatus.Text := L("StatusStopped")
        }
        this.StopFromUI()
    }

    ; ----------------------------------------------------------
    ; Toggle()
    ;   Переключатель Start/Stop. Привязан к хоткею F10.
    ; ----------------------------------------------------------
    static Toggle(*) {
        if (this.IsRunning)
            this.Stop()
        else
            this.Start()
    }

    ; ----------------------------------------------------------
    ; Tick()
    ;   Основной тик AFK-действия. Читает режим из глобальных bgState/activeState
    ;   (не из CheckBox.Value — в новом UI чекбоксов нет).
    ; ----------------------------------------------------------
    static Tick() {
        global appGui, bgState, activeState
        if (!this.IsRunning)
            return

        ; Если не фоновый режим и включена опция «только активное окно» — проверяем фокус
        if (!bgState && activeState) {
            if (!IsRobloxActive()) {
                LogMsg(L("RobloxNotActive"))
                this.SetRandomTimer()
                return
            }
        }

        ; Определяем тип действия из радиокнопок
        action := "mouse"
        if (IsObject(appGui) && appGui["RbShift"].Value)
            action := "shift"
        else if (IsObject(appGui) && appGui["RbScroll"].Value)
            action := "scroll"

        if (bgState) {
            ; Фоновый ввод без захвата фокуса
            this.QuickFocusAction(action)
        } else {
            if (action = "mouse") {
                MouseMove(1, 0, 1, "R")
                Sleep(Random(30, 80))
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

        ; Планируем следующий тик с рандомным интервалом
        this.SetRandomTimer()
    }

    ; ----------------------------------------------------------
    ; QuickFocusAction(action)
    ;   Фоновый ввод через ControlSend — не требует переключения
    ;   фокуса. После отправки добавляет случайную задержку 50–150 мс
    ;   для имитации человеческого поведения.
    ;   Параметры:
    ;     action — "shift" или "scroll"
    ;   Возвращает: true при успехе, false при ошибке.
    ; ----------------------------------------------------------
    static QuickFocusAction(action) {
        robloxHwnd := FindRobloxWindow()
        if (!robloxHwnd) {
            LogMsg(L("RobloxNotFound"))
            return false
        }

        key := (action = "shift") ? "{Shift}" : "{ScrollLock}"

        try {
            ControlSend(key,, "ahk_id " robloxHwnd)
            Sleep(Random(50, 150))
        } catch as e {
            LogMsg("ControlSend error: " e.Message)
            return false
        }

        LogMsg(action = "shift" ? L("InputShift") : L("InputScroll"))
        return true
    }
}
