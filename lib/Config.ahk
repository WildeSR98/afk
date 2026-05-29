#Requires AutoHotkey v2.0
; ============================================================
;  lib\Config.ahk
;  Centralized configuration manager (static class)
;  Reads/writes resources\settings.ini
; ============================================================

class ConfigManager {
    ; Путь к файлу настроек (всегда в resources\settings.ini рядом со скриптом)
    static Path := A_ScriptDir "\resources\settings.ini"

    ; ── Значения по умолчанию ──────────────────────────────────
    static Language         := "ru"   ; Язык интерфейса: "ru" | "en"
    static ReconnectInterval := 5000  ; Интервал авто-реконнекта (мс)
    static AFKInterval      := 120    ; Базовый интервал AFK-тика (сек)
    static AutoSearch       := 1      ; 1 = автопоиск окна Roblox при старте
    static Theme            := "dark" ; Тема UI: "dark" | "light"
    static RunOnStartup     := 0      ; 1 = добавить в автозагрузку Windows
    static HotkeyToggle     := "F10"  ; Хоткей включения/выключения AFK
    static HotkeyCapture    := "F8"   ; Хоткей захвата шаблона Reconnect

    ; ----------------------------------------------------------
    ; Load()
    ;   Загружает настройки из settings.ini в статические свойства.
    ;   Если файл отсутствует — создаёт с дефолтными значениями.
    ;   При повреждении файла (ошибка парсинга) — сбрасывает в дефолт.
    ;   Структура INI:
    ;     [Settings]  Language, HotkeyToggle, HotkeyCapture
    ;     [Search]    ReconnectInterval, AFKInterval, AutoSearch
    ;     [UI]        Theme
    ;     [System]    RunOnStartup
    ; ----------------------------------------------------------
    static Load() {
        if !FileExist(this.Path) {
            this.Save()
            return
        }
        try {
            this.Language         := IniRead(this.Path, "Settings", "Language",         "ru")
            this.HotkeyToggle     := IniRead(this.Path, "Settings", "HotkeyToggle",     "F10")
            this.HotkeyCapture    := IniRead(this.Path, "Settings", "HotkeyCapture",    "F8")
            this.ReconnectInterval := Number(IniRead(this.Path, "Search", "ReconnectInterval", "5000"))
            this.AFKInterval      := Number(IniRead(this.Path, "Search", "AFKInterval",  "120"))
            this.AutoSearch       := Number(IniRead(this.Path, "Search", "AutoSearch",   "1"))
            this.Theme            := IniRead(this.Path, "UI",     "Theme",               "dark")
            this.RunOnStartup     := Number(IniRead(this.Path, "System", "RunOnStartup", "0"))
        } catch {
            ; Если файл повреждён — сбрасываем в дефолт
            this.Save()
        }
    }

    ; ----------------------------------------------------------
    ; Save()
    ;   Записывает текущие значения свойств в settings.ini.
    ;   При ошибке записи показывает MsgBox с деталями ошибки.
    ; ----------------------------------------------------------
    static Save() {
        try {
            IniWrite(this.Language,                  this.Path, "Settings", "Language")
            IniWrite(this.HotkeyToggle,              this.Path, "Settings", "HotkeyToggle")
            IniWrite(this.HotkeyCapture,             this.Path, "Settings", "HotkeyCapture")
            IniWrite(String(this.ReconnectInterval), this.Path, "Search",   "ReconnectInterval")
            IniWrite(String(this.AFKInterval),       this.Path, "Search",   "AFKInterval")
            IniWrite(String(this.AutoSearch),        this.Path, "Search",   "AutoSearch")
            IniWrite(this.Theme,                     this.Path, "UI",       "Theme")
            IniWrite(String(this.RunOnStartup),      this.Path, "System",   "RunOnStartup")
        } catch as err {
            MsgBox("Ошибка сохранения настроек: " err.Message, "Error", "Iconx")
        }
    }

    ; ----------------------------------------------------------
    ; UpdateRegistry()
    ;   Управляет записью автозапуска в реестр Windows:
    ;   HKCU\Software\Microsoft\Windows\CurrentVersion\Run
    ;   Добавляет запись если RunOnStartup=1, удаляет если =0.
    ; ----------------------------------------------------------
    static UpdateRegistry() {
        regKey  := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"
        appName := "RobloxAFKKeeper"
        if (this.RunOnStartup) {
            try RegWrite('"' A_ScriptFullPath '"', "REG_SZ", regKey, appName)
        } else {
            try RegDelete(regKey, appName)
        }
    }
}
