; ============================================================
;  lib\LangUtils.ahk
;  Localization helpers
; ============================================================

LoadLanguage(langCode) {
    global currentLang := langCode
    if (langCode = "ru")
        LoadRussian()
    else
        LoadEnglish()
    try {
        if (!DirExist(A_ScriptDir "\resources"))
            DirCreate(A_ScriptDir "\resources")
        IniWrite(langCode, SETTINGS_INI, "Settings", "Language")
    }
}

L(key) {
    global lang
    if (IsObject(lang) && lang.Has(key))
        return lang[key]
    return key
}
