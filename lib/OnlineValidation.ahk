#Requires AutoHotkey v2.0

/*
; ============================================================
;  lib\OnlineValidation.ahk
;  Онлайн-валидация ключей (Черновик - в данный момент отключено)
; ============================================================

ValidateKeyOnline(code) {
    ; Замените на ваш реальный URL (например, ваш сервер, Webhook или Google Sheets API)
    validationUrl := "https://your-server.com/api/validate?code=" . code

    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", validationUrl, true)
        http.Send()
        http.WaitForResponse()

        response := http.ResponseText

        ; Простая проверка: если ответ содержит "VALID", возвращаем true
        ; В реальном проекте лучше парсить JSON
        if (InStr(response, "VALID")) {
            return true
        } else if (InStr(response, "REVOKED")) {
            MsgBox("Этот ключ был отозван или заблокирован сервером.", "Ошибка активации", 16)
            return false
        }
    } catch as err {
        ; Что делать, если сервер недоступен?
        ; Можно разрешить оффлайн-вход или полностью запретить запуск.
        ; LogMsg("Ошибка подключения к серверу валидации: " . err.Message)
        
        ; Для примера разрешаем fallback на оффлайн проверку:
        return "FALLBACK_OFFLINE"
    }

    return false
}
*/