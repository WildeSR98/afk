# Отчёт аудита приложения Roblox AFK Keeper v3.2

---

## 1. Структура проекта

```
afk/
├─ RobloxAFKKeeper.ahk            # Точка входа, GUI, обработчики событий
├─ RobloxAFKKeeper_test.ahk       # Копия основного скрипта (без OCR) — мусор
├─ .gitignore
│
├─ lang/
│   ├─ lang_en.ahk                # Английские строки (43 ключа)
│   └─ lang_ru.ahk                # Русские строки (43 ключа)
│
├─ lib/
│   ├─ Activation.ahk             # Лицензирование (225 строк, 9 функций)
│   ├─ AFKCore.ahk                # AFK-логика (113 строк, 5 функций)
│   ├─ GDIPlus.ahk                # Скриншоты GDI+ (37 строк, 3 функции)
│   ├─ LangUtils.ahk              # Локализация (25 строк, 2 функции)
│   ├─ Reconnect.ahk              # Авто-реконнект (238 строк, 11 функций)
│   ├─ TrayMenu.ahk               # Трей (41 строка, 5 функций)
│   └─ WindowUtils.ahk            # Окна Roblox (39 строк, 3 функции)
│
├─ vendor/OCR.ahk                  # Windows.Media.Ocr
├─ src/CodeData.ahk                # Base64-коды активации + CODES_SALT1
├─ resources/                      # license.dat, reconnect_template.png, settings.ini
├─ data/codes.bin                  # Не используется в v3.2
├─ tools/                          # build.bat, generate_codes.ahk, etc.
├─ Ahk2Exe/                       # Компилятор
├─ dist/                           # Готовые exe
└─ unlockAI (1)/                   # Мусор
```

---

## 2. Полный перечень функций по модулям

### 2.1. `RobloxAFKKeeper.ahk` (199 строк)
| Функция | Строки | Назначение |
|---------|--------|------------|
| `EnsureDirectories()` | 29–32 | Создаёт `resources/` |
| `LogMsg(msg)` | 48–55 | `[HH:mm:ss] msg` → LogEdit + автопрокрутка |
| `UpdateReconnectStatus()` | 57–65 | Обновляет текст статуса шаблона |
| `ShowMainWindow()` | 70–130 | Строит GUI (60 строк UI-кода) |
| `ToggleLanguage(*)` | 135–161 | Переключает `ru ↔ en` |
| `OnBgToggle(ctrl, *)` | 163–171 | Чекбокс «Фоновый режим» |
| `OnReconnectToggle(ctrl, *)` | 173–179 | Чекбокс «Авто-реконнект» |
| `SetupHotkeys()` | 184–187 | F10, F8 |
| **Точка входа** | 192–198 | `CheckActivation()` → `ShowMainWindow` + `SetupTray` + `SetupHotkeys` |

### 2.2. `lib/Activation.ahk` (225 строк)
| Функция | Назначение |
|---------|------------|
| `CheckActivation()` | Загружает язык, проверяет `license.dat` |
| `DecodeCodesData()` | Base64 → буфер |
| `IsCodeInData(code)` | Проверка кода в списке (XOR salt1 ⊕ salt2) |
| `ValidateLicenseFile()` | Дешифровка + проверка файла лицензии |
| `ActivateByCode(rawCode)` | Нормализация + запись `license.dat` |
| `ShowActivationWindow()` | GUI окна активации |
| `ToggleActivationLang(*)` | Переключение языка в окне активации |
| `TryActivate(rawCode)` | Обёртка: активация → инициализация |
| `B64Decode(str)` | AHK v2 Base64-декодер |

### 2.3. `lib/AFKCore.ahk` (113 строк)
| Функция | Назначение |
|---------|------------|
| `StartAFK(*)` | `SetTimer(AFKTick, interval*1000)` ← **фиксированный интервал** |
| `StopAFK(*)` | Остановка таймера |
| `ToggleAFK(*)` | Переключатель |
| `AFKTick()` | Основной тик: mouse/shift/scroll |
| `QuickFocusAction(action)` | Фон: переключение фокуса → действие → возврат ← **использует `SendInput`** |

### 2.4. `lib/Reconnect.ahk` (238 строк)
| Функция | Назначение |
|---------|------------|
| `ColorDistance(c1, c2)` | Манхэттенское расстояние RGB |
| `CaptureTemplate(*)` | Скриншот 140×50 → `reconnect_template.png` |
| `FindReconnectByOCR()` | OCR → поиск «Reconnect» |
| `FindReconnectByTemplate()` | ImageSearch по шаблону |
| `FindReconnectByColor()` | Поиск по палитре цветов |
| `FindReconnectButton()` | Каскад: OCR → шаблон → цвет |
| `DoReconnectClick(x, y)` | Фокус → клик → возврат |
| `StartReconnect()` | `SetTimer(ReconnectTick, 5000)` ← **хардкод 5 сек** |
| `StopReconnect()` | Остановка |
| `ReconnectTick()` | Тик: ищет кнопку, кликает, 3 сек пауза |

### 2.5. Остальные модули
- **`WindowUtils.ahk`**: `FindRobloxWindow()`, `GetRobloxRect()`, `IsRobloxActive()`
- **`GDIPlus.ahk`**: `Gdip_Startup()`, `Gdip_ScreenCapture()`, `Gdip_SaveHBITMAPToFile()` ← **нет `Gdip_DisposeImage`**
- **`LangUtils.ahk`**: `LoadLanguage()`, `L(key)` — переменная `lang` (Map)
- **`TrayMenu.ahk`**: `SetupTray()`, `ShowGuiFromTray()`, `HideToTray()`, `OnClosing()` ← **скрывает в трей**, `ExitHandler()` ← **нет очистки ресурсов**

---

## 3. Выявленные проблемы

### 🔴 Критические
| # | Проблема | Файл | Строки |
|---|----------|------|--------|
| 1 | Фиксированный таймер AFK — легко детектируется | `AFKCore.ahk` | 20 |
| 2 | `SendInput` вместо `ControlSend` — требует фокус | `AFKCore.ahk` | 67–105 |
| 3 | Утечка GDI+ — нет `Gdip_DisposeImage`, `DeleteObject` в циклах | `GDIPlus.ahk`, `Reconnect.ahk` | |
| 4 | Нет `Gdip_Shutdown()` при выходе | `TrayMenu.ahk` | 38–40 |
| 5 | Хардкод `SetTimer(ReconnectTick, 5000)` | `Reconnect.ahk` | 212 |
| 6 | `license.dat` копируется — нет HWID | `Activation.ahk` | 76–145 |

### 🟡 Важные
| # | Проблема |
|---|----------|
| 7 | **Баг**: `appGui["HotkeysLabel"]` — контрол без `v`-переменной → краш при смене языка |
| 8 | Нет кнопки «Настройки», нет окна Settings |
| 9 | `settings.ini` — только `Language`, нет интервалов |
| 10 | 8 глобальных переменных, спагетти-архитектура |
| 11 | Белый фон UI — не геймерский |
| 12 | `Edit` для логов — медленный при частых вставках |

### 🟢 Мусор
| # | Проблема |
|---|----------|
| 13 | `RobloxAFKKeeper_test.ahk` — копия, не тесты |
| 14 | `unlockAI (1)/`, `data/codes.bin` — не используются |
| 15 | Нет README.md |

---

## 4. План работ — 7 фаз с кодом

---

### Фаза 1 — Конфигурация и Настройки 🔴

#### 1.1. Создать `lib/Config.ahk` — статический класс `ConfigManager`

```ahk
#Requires AutoHotkey v2.0

class ConfigManager {
    static Path := A_ScriptDir "\resources\settings.ini"

    ; Значения по умолчанию
    static Language := "ru"
    static ReconnectInterval := 5000
    static AFKInterval := 120
    static AutoSearch := 1
    static Theme := "dark"

    static Load() {
        if !FileExist(this.Path) {
            this.Save()
            return
        }
        try {
            this.Language := IniRead(this.Path, "Settings", "Language", "ru")
            this.ReconnectInterval := Number(IniRead(this.Path, "Search", "ReconnectInterval", "5000"))
            this.AFKInterval := Number(IniRead(this.Path, "Search", "AFKInterval", "120"))
            this.AutoSearch := Number(IniRead(this.Path, "Search", "AutoSearch", "1"))
            this.Theme := IniRead(this.Path, "UI", "Theme", "dark")
        } catch {
            this.Save()
        }
    }

    static Save() {
        try {
            IniWrite(this.Language, this.Path, "Settings", "Language")
            IniWrite(String(this.ReconnectInterval), this.Path, "Search", "ReconnectInterval")
            IniWrite(String(this.AFKInterval), this.Path, "Search", "AFKInterval")
            IniWrite(String(this.AutoSearch), this.Path, "Search", "AutoSearch")
            IniWrite(this.Theme, this.Path, "UI", "Theme")
        } catch as err {
            MsgBox("Ошибка сохранения настроек: " err.Message, "Error", "Iconx")
        }
    }
}
```

**Затрагиваемые файлы**: `RobloxAFKKeeper.ahk` (добавить `#Include lib\Config.ahk` + вызов `ConfigManager.Load()`).

#### 1.2. Обновить `lib/Reconnect.ahk` — динамический интервал

Заменить `StartReconnect()` (строки 201–213):
```ahk
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
    SetTimer(ReconnectTick, ConfigManager.ReconnectInterval)  ; ← вместо 5000
}
```

Добавить в конец файла:
```ahk
UpdateSearchTimer() {
    global reconnectRunning
    if (reconnectRunning) {
        SetTimer(ReconnectTick, 0)
        SetTimer(ReconnectTick, ConfigManager.ReconnectInterval)
        LogMsg("Reconnect interval updated: " ConfigManager.ReconnectInterval " ms")
    }
}
```

#### 1.3. Добавить кнопку «Настройки» в `ShowMainWindow()`

В `RobloxAFKKeeper.ahk`, после кнопок Start/Stop/Tray (строка ~122):
```ahk
; Control buttons
appGui.AddButton("vStartBtn xm+40 y+25 w100", L("Start")).OnEvent("Click", StartAFK)
appGui.AddButton("vStopBtn x+10 w100 Disabled", L("Stop")).OnEvent("Click", StopAFK)
appGui.AddButton("vTrayBtn x+10 w100", L("ToTray")).OnEvent("Click", HideToTray)
appGui.AddButton("vSettingsBtn x+10 w100", L("SettingsBtn")).OnEvent("Click", (*) => ShowSettingsWindow())
```

#### 1.4. Создать `ShowSettingsWindow()` и `OnSaveSettings()`

Добавить в `RobloxAFKKeeper.ahk`:
```ahk
ShowSettingsWindow() {
    global appGui
    settingsGui := Gui("+Owner" appGui.Hwnd " +ToolWindow", L("SettingsTitle"))
    settingsGui.SetFont("s9", "Segoe UI")
    settingsGui.MarginX := 15
    settingsGui.MarginY := 10

    settingsGui.AddGroupBox("w300 h160", L("SearchGroup"))

    settingsGui.AddText("xm+10 yp+25 w280", L("SearchIntervalLabel"))
    settingsGui.AddEdit("vSearchIntervalEdit w120 Number", ConfigManager.ReconnectInterval)

    settingsGui.AddText("w280 y+10", L("AFKIntervalLabel"))
    settingsGui.AddEdit("vAFKIntervalEdit w120 Number", ConfigManager.AFKInterval)

    settingsGui.AddCheckBox("vAutoSearchChk y+10 Checked" ConfigManager.AutoSearch, L("AutoSearchLabel"))

    btnSave := settingsGui.AddButton("xm+40 y+20 w100", L("SaveBtn"))
    btnSave.OnEvent("Click", (ctrl, *) => OnSaveSettings(settingsGui))

    btnCancel := settingsGui.AddButton("x+20 yp w100", L("CancelBtn"))
    btnCancel.OnEvent("Click", (*) => settingsGui.Destroy())

    settingsGui.Show("AutoSize Center")
}

OnSaveSettings(guiObj) {
    saved := guiObj.Submit()

    ConfigManager.ReconnectInterval := Number(saved.SearchIntervalEdit)
    ConfigManager.AFKInterval := Number(saved.AFKIntervalEdit)
    ConfigManager.AutoSearch := saved.AutoSearchChk
    ConfigManager.Save()

    UpdateSearchTimer()
    LogMsg(L("SettingsSaved"))
}
```

#### 1.5. Обновить локализацию

**`lang/lang_ru.ahk`** — добавить в `LoadRussian()`:
```ahk
    lang["SettingsBtn"] := "Настройки"
    lang["SettingsTitle"] := "Настройки программы"
    lang["SearchGroup"] := "Параметры поиска"
    lang["SearchIntervalLabel"] := "Частота поиска окна Roblox (мс):"
    lang["AFKIntervalLabel"] := "Интервал кликов AFK (сек):"
    lang["AutoSearchLabel"] := "Автоматически искать окно при запуске"
    lang["SaveBtn"] := "Сохранить"
    lang["CancelBtn"] := "Отмена"
    lang["SettingsSaved"] := "Настройки сохранены в settings.ini"
```

**`lang/lang_en.ahk`** — добавить в `LoadEnglish()`:
```ahk
    lang["SettingsBtn"] := "Settings"
    lang["SettingsTitle"] := "Application Settings"
    lang["SearchGroup"] := "Search Parameters"
    lang["SearchIntervalLabel"] := "Roblox Window Search Interval (ms):"
    lang["AFKIntervalLabel"] := "AFK Click Interval (sec):"
    lang["AutoSearchLabel"] := "Auto-search Roblox window on startup"
    lang["SaveBtn"] := "Save"
    lang["CancelBtn"] := "Cancel"
    lang["SettingsSaved"] := "Settings saved to settings.ini"
```

#### 1.6. Инициализация конфига при старте

В `RobloxAFKKeeper.ahk`, перед точкой входа (после `#Include`):
```ahk
#Include lib\Config.ahk

; ... (остальные #Include) ...

ConfigManager.Load()
```

А в `lib/LangUtils.ahk` — заменить прямой `IniWrite` на использование `ConfigManager`:
```ahk
LoadLanguage(langCode) {
    global currentLang := langCode
    if (langCode = "ru")
        LoadRussian()
    else
        LoadEnglish()
    try {
        ConfigManager.Language := langCode
        ConfigManager.Save()
    }
}
```

---

### Фаза 2 — Исправление багов и утечек 🔴

#### 2.1. Исправить баг `HotkeysLabel`

В `RobloxAFKKeeper.ahk`, строка 83 — добавить `vHotkeysLabel`:
```ahk
; БЫЛО:
appGui.AddText("xm y10 w400 Center c808080", L("Hotkeys")).SetFont("s9")

; СТАЛО:
appGui.AddText("vHotkeysLabel xm y10 w400 Center c808080", L("Hotkeys")).SetFont("s9")
```

#### 2.2. Очистка ресурсов при выходе

Заменить `ExitHandler` в `lib/TrayMenu.ahk`:
```ahk
ExitHandler(*) {
    global gdipToken

    ; 1. Остановить все таймеры
    SetTimer(AFKTick, 0)
    SetTimer(ReconnectTick, 0)

    ; 2. Освободить GDI+
    if (gdipToken) {
        DllCall("gdiplus\GdiplusShutdown", "Ptr", gdipToken)
        gdipToken := 0
    }

    ; 3. Завершить
    ExitApp()
}
```

#### 2.3. Добавить `Gdip_DisposeImage` в `lib/GDIPlus.ahk`

Добавить в конец файла:
```ahk
Gdip_DisposeImage(pBitmap) {
    if (pBitmap)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
}
```

#### 2.4. `try/catch` для OCR и ImageSearch в `lib/Reconnect.ahk`

Обернуть `ImageSearch` в `FindReconnectByTemplate()`:
```ahk
FindReconnectByTemplate() {
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
```

---

### Фаза 3 — Anti-Cheat Bypass 🔴

> **Цель**: Сделать AFK невидимым для поведенческого анализа Roblox.

#### 3.1. Рандомизация таймера (Fuzzy Anti-AFK)

В `lib/AFKCore.ahk` — заменить фиксированный `SetTimer`:
```ahk
SetRandomAFKTimer() {
    global afkRunning
    if (!afkRunning)
        return
    baseInterval := ConfigManager.AFKInterval * 1000
    minTime := Integer(baseInterval * 0.7)
    maxTime := Integer(baseInterval * 1.3)
    RandomTime := Random(minTime, maxTime)
    SetTimer(AFKTick, -RandomTime)  ; минус = однократный
}

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
    SetRandomAFKTimer()  ; ← вместо SetTimer(AFKTick, interval * 1000)
}
```

В конце `AFKTick()` — добавить перезапуск:
```ahk
AFKTick() {
    ; ... (существующая логика) ...
    
    ; В самом конце функции — перезапуск со случайным интервалом
    SetRandomAFKTimer()
}
```

#### 3.2. `ControlSend` вместо `SendInput` для фонового режима

В `lib/AFKCore.ahk` — заменить `QuickFocusAction()`:
```ahk
QuickFocusAction(action) {
    robloxHwnd := FindRobloxWindow()
    if (!robloxHwnd) {
        LogMsg(L("RobloxNotFound"))
        return false
    }
    ; Используем ControlSend — не переключаем фокус вообще
    key := (action = "shift") ? "{Shift}" : "{ScrollLock}"
    try {
        ControlSend(key,, "ahk_id " robloxHwnd)
        ; Случайная задержка 50–150 мс для имитации человека
        Sleep(Random(50, 150))
    } catch as e {
        LogMsg("ControlSend error: " e.Message)
        return false
    }
    LogMsg(action = "shift" ? L("InputShift") : L("InputScroll"))
    return true
}
```

#### 3.3. `ControlClick` в `DoReconnectClick`

В `lib/Reconnect.ahk` — упрощённый `DoReconnectClick`:
```ahk
DoReconnectClick(x, y) {
    global robloxHwnd
    if (!robloxHwnd || !DllCall("IsWindow", "Ptr", robloxHwnd))
        return
    try {
        ; Вычисляем координаты относительно окна
        WinGetPos(&wx, &wy,,, "ahk_id " robloxHwnd)
        relX := x - wx
        relY := y - wy
        ControlClick("x" relX " y" relY, "ahk_id " robloxHwnd,, "Left", 1)
        Sleep(Random(80, 200))
    } catch as e {
        LogMsg("ControlClick error: " e.Message)
    }
}
```

#### 3.4. Кеширование позиции кнопки Reconnect

В `lib/Reconnect.ahk` — добавить глобальную переменную и оптимизацию:
```ahk
global lastReconnectPos := 0

ReconnectTick() {
    global reconnectRunning, robloxHwnd, lastReconnectPos
    if (!reconnectRunning)
        return
    if (!DllCall("IsWindow", "Ptr", robloxHwnd)) {
        LogMsg("Roblox window closed, reconnect stopped")
        StopReconnect()
        return
    }
    
    ; Сначала проверяем кешированную позицию (быстро)
    pos := 0
    if (IsObject(lastReconnectPos)) {
        ; Проверяем ±50px от прошлой позиции
        ; ... (упрощённая проверка)
    }
    
    if (!IsObject(pos))
        pos := FindReconnectButton()
    
    if (IsObject(pos)) {
        lastReconnectPos := pos
        LogMsg(L("ReconnectFound") " " pos.X "," pos.Y)
        DoReconnectClick(pos.X, pos.Y)
        Sleep(3000)
    }
}
```

---

### Фаза 4 — Тёмная тема и UI/UX 🟡

#### 4.1. Палитра

| Элемент | Цвет |
|---------|------|
| Фон окна | `0x121212` |
| Фон карточек/GroupBox | `0x2D2D2D` |
| Текст основной | `0xE0E0E0` |
| Текст приглушённый | `0x808080` |
| Акцент активный | `0x00C853` (зелёный) |
| Акцент неактивный | `0xFF5252` (красный) |
| Акцент кнопок | `0x7C4DFF` (фиолетовый) |

#### 4.2. Применение в `ShowMainWindow()`

```ahk
ShowMainWindow() {
    global appGui
    appGui := Gui("+MinSize520x700", L("WindowTitle"))
    appGui.BackColor := "121212"
    appGui.SetFont("s10 cE0E0E0", "Segoe UI")
    appGui.MarginX := 15
    appGui.MarginY := 10
    ; ...
}
```

Аналогично для `ShowActivationWindow()` и `ShowSettingsWindow()`.

#### 4.3. ListView вместо Edit для логов

```ahk
; БЫЛО:
appGui.AddEdit("vLogEdit xm y+5 w470 h150 ReadOnly -Wrap VScroll")

; СТАЛО:
appGui.AddListView("vLogList xm y+5 w470 h150 +NoSortHdr -Hdr Background2D2D2D cE0E0E0", ["Log"])
```

`LogMsg()` → заменить `.Value .=` на:
```ahk
LogMsg(msg) {
    global appGui
    if (!IsObject(appGui))
        return
    timeStr := FormatTime(,"HH:mm:ss")
    appGui["LogList"].Add(, "[" timeStr "] " msg)
    appGui["LogList"].Modify(appGui["LogList"].GetCount(), "Vis")  ; прокрутка вниз
}
```

#### 4.4. Кнопки `+Flat`

```ahk
appGui.AddButton("vStartBtn +Flat xm+40 y+25 w100", L("Start"))
```

---

### Фаза 5 — ООП рефакторинг 🟡

#### 5.1. Класс `RobloxAFKKeeper`

```ahk
class RobloxAFKKeeper {
    static Version := "3.3"

    IsActivated := false
    IsRunning := false
    ReconnectRunning := false
    MainGui := ""
    RobloxHwnd := 0
    GdipToken := 0

    __New() {
        ConfigManager.Load()
    }

    Start() {
        if (!CheckActivation()) {
            return
        }
        this.ShowMainInterface()
        this.SetupTray()
        this.SetupHotkeys()
    }

    Shutdown() {
        SetTimer(AFKTick, 0)
        SetTimer(ReconnectTick, 0)
        if (this.GdipToken)
            DllCall("gdiplus\GdiplusShutdown", "Ptr", this.GdipToken)
        ExitApp()
    }
}

App := RobloxAFKKeeper()
App.Start()
```

#### 5.2. Класс `ReconnectManager`
- API: `Start()`, `Stop()`, `IsRunning()`, `SetInterval(ms)`, `Tick()`

#### 5.3. Класс `AFKEngine`
- API: `Start()`, `Stop()`, `Toggle()`, `Tick()`

---

### Фаза 6 — HWID-защита лицензии 🟡

#### 6.1. Функция `GetHWID()`

```ahk
GetHWID() {
    objWMIService := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
    colDisks := objWMIService.ExecQuery("Select SerialNumber from Win32_DiskDrive")
    for objDisk in colDisks {
        if (objDisk.SerialNumber != "")
            return Trim(objDisk.SerialNumber)
    }
    return "DEFAULT_HWID"
}
```

#### 6.2. Привязка лицензии
- `ActivateByCode()`: записывать `code ⊕ salt1 ⊕ HWID_hash`
- `ValidateLicenseFile()`: проверять текущий HWID
- Миграция: перезапись `license.dat` при первом запуске после обновления

#### 6.3. Обработка смены железа
- Если HWID изменился → окно: «Обнаружено новое оборудование. Введите код повторно.»

---

### Фаза 7 — Документация и чистка ⬇️

- **7.1** Создать `README.md` (требования, сборка, запуск)
- **7.2** Удалить `unlockAI (1)/`, `data/codes.bin`, `RobloxAFKKeeper_test.ahk`
- **7.3** Докстринги к каждой функции в `lib/*.ahk`
- **7.4** Логирование в файл `data/afk.log` (ротация 1 МБ)

---

## 5. Порядок выполнения и оценка

```
Фаза 2 ──→ Фаза 1 ──→ Фаза 3 ──→ Фаза 4 ──→ Фаза 5 ──→ Фаза 6 ──→ Фаза 7
(Баги)     (Config +   (Anti-     (Тёмная    (ООП        (HWID       (Доки)
            Settings)   Cheat)     тема)      классы)     защита)
```

| Фаза | Оценка | Файлы |
|------|--------|-------|
| 2 — Баги | ~1 ч | `RobloxAFKKeeper.ahk`, `TrayMenu.ahk`, `GDIPlus.ahk`, `Reconnect.ahk` |
| 1 — Config + Settings | ~4 ч | `Config.ahk` **(новый)**, `RobloxAFKKeeper.ahk`, `Reconnect.ahk`, `LangUtils.ahk`, `lang_*.ahk` |
| 3 — Anti-Cheat | ~3 ч | `AFKCore.ahk`, `Reconnect.ahk` |
| 4 — Тёмная тема | ~1 ч | `RobloxAFKKeeper.ahk`, `Activation.ahk` |
| 5 — ООП | ~6 ч | Все файлы |
| 6 — HWID | ~3 ч | `Activation.ahk`, `tools/generate_codes.ahk` |
| 7 — Документация | ~2 ч | `README.md` **(новый)**, удаление мусора |

**Итого: ~20 часов**

---

*Отчёт сгенерирован 2026‑05‑28. Объединены результаты внутреннего аудита и стороннего анализа.*
