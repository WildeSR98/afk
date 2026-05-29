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
        ConfigManager.Language := langCode
        ConfigManager.Save()
    }
}

L(key) {
    global lang
    if (IsObject(lang) && lang.Has(key))
        return lang[key]
    return key
}
