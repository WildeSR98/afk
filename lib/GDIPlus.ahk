; ============================================================
;  lib\GDIPlus.ahk
;  GDI+ helpers for screenshot capture
; ============================================================

Gdip_Startup() {
    global gdipToken
    if (gdipToken)
        return
    si := Buffer(A_PtrSize = 8 ? 24 : 12, 0)
    NumPut("Int", 1, si)
    DllCall("gdiplus\GdiplusStartup", "Ptr*", &gdipToken:=0, "Ptr", si, "Ptr", 0)
}

Gdip_ScreenCapture(x, y, w, h) {
    hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
    hBitmap := DllCall("CreateCompatibleBitmap", "Ptr", hdc, "Int", w, "Int", h, "Ptr")
    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBitmap)
    DllCall("BitBlt", "Ptr", hdcMem, "Int", 0, "Int", 0, "Int", w, "Int", h,
            "Ptr", hdc, "Int", x, "Int", y, "UInt", 0x00CC0020)
    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
    return hBitmap
}

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
