; ============================================================
;  lib\GDIPlus.ahk
;  GDI+ helpers for screenshot capture and image management
;  Используется: Reconnect.ahk (захват шаблона кнопки)
; ============================================================

; ----------------------------------------------------------
; Gdip_Startup()
;   Инициализирует GDI+ один раз за сеанс.
;   Токен сохраняется в глобальной переменной gdipToken.
;   Повторный вызов безопасен (idempotent).
; ----------------------------------------------------------
Gdip_Startup() {
    global gdipToken
    if (gdipToken)
        return
    si := Buffer(A_PtrSize = 8 ? 24 : 12, 0)
    NumPut("Int", 1, si)
    DllCall("gdiplus\GdiplusStartup", "Ptr*", &gdipToken:=0, "Ptr", si, "Ptr", 0)
}

; ----------------------------------------------------------
; Gdip_ScreenCapture(x, y, w, h) → HBITMAP
;   Делает скриншот прямоугольной области экрана.
;   Параметры:
;     x, y — левый верхний угол (экранные координаты)
;     w, h  — ширина и высота в пикселях
;   Возвращает: HBITMAP (необходимо удалить через DeleteObject/Gdip_DisposeImage)
;   ⚠️ Вызывающий код обязан освободить возвращённый дескриптор!
; ----------------------------------------------------------
Gdip_ScreenCapture(x, y, w, h) {
    hdc    := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
    hBitmap := DllCall("CreateCompatibleBitmap", "Ptr", hdc, "Int", w, "Int", h, "Ptr")
    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBitmap)
    DllCall("BitBlt", "Ptr", hdcMem, "Int", 0, "Int", 0, "Int", w, "Int", h,
            "Ptr", hdc, "Int", x, "Int", y, "UInt", 0x00CC0020)
    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
    return hBitmap
}

; ----------------------------------------------------------
; Gdip_SaveHBITMAPToFile(hBitmap, filePath)
;   Сохраняет HBITMAP как PNG-файл через GDI+.
;   Автоматически инициализирует GDI+ если нужно.
;   Освобождает pBitmap и hBitmap после сохранения.
;   Параметры:
;     hBitmap  — дескриптор растрового изображения (из Gdip_ScreenCapture)
;     filePath — полный путь к выходному PNG-файлу
; ----------------------------------------------------------
Gdip_SaveHBITMAPToFile(hBitmap, filePath) {
    Gdip_Startup()
    pBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hBitmap, "Ptr", 0, "Ptr*", &pBitmap)
    clsid := Buffer(16)
    DllCall("ole32\CLSIDFromString", "WStr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", clsid)
    DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "WStr", filePath, "Ptr", clsid, "Ptr", 0)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
    DllCall("DeleteObject", "Ptr", hBitmap)
}

; ----------------------------------------------------------
; Gdip_DisposeImage(pBitmap)
;   Освобождает GDI+ pBitmap (объект Image/Bitmap).
;   Безопасно принимает 0 (нет операции).
;   ⚠️ Вызывать после каждого GdipCreateBitmapFromHBITMAP!
; ----------------------------------------------------------
Gdip_DisposeImage(pBitmap) {
    if (pBitmap)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
}

; ----------------------------------------------------------
; Gdip_Shutdown()
;   Освобождает GDI+ токен при выходе из приложения.
;   Вызывается из ExitHandler() в TrayMenu.ahk.
;   Предотвращает утечку неуправляемых ресурсов Windows.
; ----------------------------------------------------------
Gdip_Shutdown() {
    global gdipToken
    if (gdipToken) {
        DllCall("gdiplus\GdiplusShutdown", "Ptr", gdipToken)
        gdipToken := 0
    }
}
