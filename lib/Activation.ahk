; ============================================================
;  lib\Activation.ahk
;  License code validation and activation window
;
;  Codes are embedded in src\CodeData.ahk as a Base64 string.
;  No external codes.bin file is needed in dist\.
; ============================================================

; APP_SALT2 must match the value in tools\generate_codes.ahk
global APP_SALT2 := [0xA3, 0x7F, 0xC1, 0x5E, 0x29, 0x88, 0xD4, 0x0B, 0x6E, 0xF2, 0x3A, 0x91, 0x55, 0xBC, 0x47, 0xE6]

CheckActivation() {
    global currentLang, LICENSE_FILE, SETTINGS_INI
    if (FileExist(SETTINGS_INI)) {
        try currentLang := IniRead(SETTINGS_INI, "Settings", "Language", "ru")
    }
    LoadLanguage(currentLang)

    if (FileExist(LICENSE_FILE) && ValidateLicenseFile()) {
        isActivated := true
        return true
    }
    ShowActivationWindow()
    return false
}

; ---- Decode embedded codes from CODES_DATA (Base64) into memory ----
DecodeCodesData() {
    global CODES_DATA, CODES_SALT1, APP_SALT2

    raw := B64Decode(CODES_DATA)
    if (!raw || raw.Size < 4 + 16)
        return false

    ; First 4 bytes are SALT1 (stored for self-consistency check)
    ; actual salt1 value comes from CODES_SALT1 constant
    salt1_0 := (CODES_SALT1 >> 24) & 0xFF
    salt1_1 := (CODES_SALT1 >> 16) & 0xFF
    salt1_2 := (CODES_SALT1 >>  8) & 0xFF
    salt1_3 :=  CODES_SALT1        & 0xFF
    salt1 := [salt1_0, salt1_1, salt1_2, salt1_3]

    return raw
}

IsCodeInData(code) {
    global CODES_DATA, CODES_SALT1, APP_SALT2

    raw := B64Decode(CODES_DATA)
    if (!raw || raw.Size < 4 + 16)
        return false

    salt1_0 := (CODES_SALT1 >> 24) & 0xFF
    salt1_1 := (CODES_SALT1 >> 16) & 0xFF
    salt1_2 := (CODES_SALT1 >>  8) & 0xFF
    salt1_3 :=  CODES_SALT1        & 0xFF
    salt1 := [salt1_0, salt1_1, salt1_2, salt1_3]

    codeCount := (raw.Size - 4) // 16
    Loop codeCount {
        blockOffset := 4 + (A_Index - 1) * 16
        decrypted := ""
        Loop 16 {
            i := A_Index
            enc := NumGet(raw, blockOffset + i - 1, "UChar")
            s1  := salt1[Mod(i - 1, 4) + 1]
            s2  := APP_SALT2[Mod(i - 1, 16) + 1]
            decrypted .= Chr(enc ^ s1 ^ s2)
        }
        if (decrypted == code)
            return true
    }
    return false
}

ValidateLicenseFile() {
    global LICENSE_FILE, CODES_SALT1, APP_SALT2

    if (!FileExist(LICENSE_FILE))
        return false

    licFile := FileOpen(LICENSE_FILE, "r")
    if (!licFile || licFile.Length != 16) {
        if (licFile)
            licFile.Close()
        return false
    }
    enc := Buffer(16)
    licFile.RawRead(enc, 16)
    licFile.Close()

    ; License is stored XOR'd with CODES_SALT1 bytes
    salt1_0 := (CODES_SALT1 >> 24) & 0xFF
    salt1_1 := (CODES_SALT1 >> 16) & 0xFF
    salt1_2 := (CODES_SALT1 >>  8) & 0xFF
    salt1_3 :=  CODES_SALT1        & 0xFF
    salt1 := [salt1_0, salt1_1, salt1_2, salt1_3]

    decrypted := ""
    Loop 16 {
        s := salt1[Mod(A_Index - 1, 4) + 1]
        c := NumGet(enc, A_Index - 1, "UChar")
        decrypted .= Chr(c ^ s)
    }
    return IsCodeInData(decrypted)
}

ActivateByCode(rawCode) {
    global LICENSE_FILE, CODES_SALT1, APP_SALT2

    code := StrReplace(StrReplace(rawCode, "-", ""), " ", "")
    code := StrUpper(code)
    if (StrLen(code) != 16) {
        MsgBox(L("ActivationCodeLen"), L("ActivationTitle"), 48)
        return false
    }
    if (!IsCodeInData(code)) {
        MsgBox(L("ActivationError"), L("ActivationTitle"), 48)
        return false
    }

    ; Save license: code XOR'd with CODES_SALT1
    salt1_0 := (CODES_SALT1 >> 24) & 0xFF
    salt1_1 := (CODES_SALT1 >> 16) & 0xFF
    salt1_2 := (CODES_SALT1 >>  8) & 0xFF
    salt1_3 :=  CODES_SALT1        & 0xFF
    salt1 := [salt1_0, salt1_1, salt1_2, salt1_3]

    licFile := FileOpen(LICENSE_FILE, "w")
    if (!licFile) {
        MsgBox("Cannot write license file!", "Error", 16)
        return false
    }
    enc := Buffer(16)
    Loop 16 {
        s := salt1[Mod(A_Index - 1, 4) + 1]
        c := Ord(SubStr(code, A_Index, 1))
        NumPut("UChar", c ^ s, enc, A_Index - 1)
    }
    licFile.RawWrite(enc, 16)
    licFile.Close()

    MsgBox(L("ActivationSuccess"), L("ActivationTitle"), 64)
    return true
}

ShowActivationWindow() {
    global activationGui
    activationGui := Gui("+AlwaysOnTop +MinSize360x200", L("ActivationTitle"))
    activationGui.SetFont("s10", "Segoe UI")
    activationGui.BackColor := "FFFFFF"
    activationGui.MarginX := 20
    activationGui.MarginY := 15

    activationGui.AddText("vPromptText w320 Center", L("ActivationPrompt"))
    activationGui.AddText("vFormatText w320 Center c808080", L("ActivationFormat")).SetFont("s9")
    codeEdit := activationGui.AddEdit("vCodeEdit w320 Center UpperCase y+10")

    btn := activationGui.AddButton("vActivateBtn w320 Default y+15", L("ActivateBtn"))
    btn.OnEvent("Click", (*) => TryActivate(codeEdit.Value))

    langBtn := activationGui.AddButton("vLangBtn w80 y+10", L("LangBtn"))
    langBtn.OnEvent("Click", ToggleActivationLang)

    activationGui.OnEvent("Close", (*) => ExitApp())
    activationGui.Show("AutoSize Center")
}

ToggleActivationLang(*) {
    global activationGui, currentLang
    currentLang := currentLang = "ru" ? "en" : "ru"
    LoadLanguage(currentLang)
    activationGui.Title := L("ActivationTitle")
    activationGui["LangBtn"].Text := L("LangBtn")
    activationGui["PromptText"].Text := L("ActivationPrompt")
    activationGui["FormatText"].Text := L("ActivationFormat")
    activationGui["ActivateBtn"].Text := L("ActivateBtn")
}

TryActivate(rawCode) {
    global activationGui, isActivated
    if (ActivateByCode(rawCode)) {
        isActivated := true
        activationGui.Destroy()
        ShowMainWindow()
        SetupTray()
        SetupHotkeys()
    }
}

; ============================================================
;  Base64 decoder (pure AHK v2)
; ============================================================
B64Decode(str) {
    chars := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    str := StrReplace(str, "=", "")
    n := StrLen(str)
    outSize := (n * 3) // 4
    buf := Buffer(outSize, 0)
    outPos := 0
    i := 1
    while (i <= n - 3) {
        c0 := InStr(chars, SubStr(str, i,   1)) - 1
        c1 := InStr(chars, SubStr(str, i+1, 1)) - 1
        c2 := InStr(chars, SubStr(str, i+2, 1)) - 1
        c3 := InStr(chars, SubStr(str, i+3, 1)) - 1
        if (c0 < 0 || c1 < 0) {
            i += 4
            continue
        }
        NumPut("UChar", (c0 << 2) | (c1 >> 4), buf, outPos++)
        if (c2 >= 0)
            NumPut("UChar", ((c1 & 0xF) << 4) | (c2 >> 2), buf, outPos++)
        if (c3 >= 0)
            NumPut("UChar", ((c2 & 0x3) << 6) | c3, buf, outPos++)
        i += 4
    }
    return buf
}
