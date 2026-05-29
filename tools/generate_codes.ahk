#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
;  Roblox AFK Keeper — Code Generator (Developer Tool)
;
;  Generates activation codes and embeds them directly
;  into src\CodeData.ahk as a double-encrypted Base64 string.
;
;  ⚠ NEVER commit this file or codes.txt to git!
;  ⚠ Run from: tools\ folder (or via build.bat)
; ============================================================

CODE_COUNT  := 1000
CODE_LENGTH := 16
CHARS       := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

; Paths
ROOT_DIR    := A_ScriptDir "\.."
TXT_PATH    := A_ScriptDir "\codes.txt"  ; stays in tools\ (gitignored)
SRC_DIR     := ROOT_DIR "\src"
CODEDATA    := SRC_DIR "\CodeData.ahk"

; ---- APP_SALT2: second XOR layer, hard-coded constant ----
; This value is also duplicated in lib\Activation.ahk
; Change both together if you rotate keys.
APP_SALT2 := [0xA3, 0x7F, 0xC1, 0x5E, 0x29, 0x88, 0xD4, 0x0B, 0x6E, 0xF2, 0x3A, 0x91, 0x55, 0xBC, 0x47, 0xE6]

; ---- Generate random 4-byte SALT1 (cryptographically secure) ----
salt1 := Buffer(4)
ntStatus := DllCall("bcrypt.dll\BCryptGenRandom", "Ptr", 0, "Ptr", salt1, "UInt", 4, "UInt", 0)
if (ntStatus != 0) {
    Loop 4 {
        b := Random(0, 255)
        NumPut("UChar", b, salt1, A_Index - 1)
    }
}

if (!DirExist(SRC_DIR))
    DirCreate(SRC_DIR)

txtFile := FileOpen(TXT_PATH, "w")
if (!txtFile) {
    MsgBox("Failed to create codes.txt!", "Error", 16)
    ExitApp()
}

; Collect all encrypted blocks into a binary buffer
; Each code: 16 bytes XOR salt1, then XOR APP_SALT2
totalBytes := 4 + CODE_COUNT * 16  ; 4 bytes salt1 header + codes
binBuf := Buffer(totalBytes, 0)

; Write salt1 at position 0
Loop 4 {
    NumPut("UChar", NumGet(salt1, A_Index - 1, "UChar"), binBuf, A_Index - 1)
}

offset := 4
Loop CODE_COUNT {
    ; Generate raw code
    code := ""
    Loop CODE_LENGTH {
        idx := Random(1, 36)
        code .= SubStr(CHARS, idx, 1)
    }

    ; Format for codes.txt
    formatted := SubStr(code, 1, 4) "-" SubStr(code, 5, 4) "-" SubStr(code, 9, 4) "-" SubStr(code, 13, 4)
    txtFile.WriteLine(formatted)

    ; Encrypt: XOR with salt1 (cyclic 4 bytes), then XOR with APP_SALT2 (cyclic 16 bytes)
    Loop CODE_LENGTH {
        i := A_Index
        raw := Ord(SubStr(code, i, 1))
        s1  := NumGet(salt1, Mod(i - 1, 4), "UChar")
        s2  := APP_SALT2[Mod(i - 1, 16) + 1]
        NumPut("UChar", raw ^ s1 ^ s2, binBuf, offset + i - 1)
    }
    offset += 16
}

txtFile.Close()

; ---- Base64 encode the buffer ----
b64 := B64Encode(binBuf, totalBytes)

; ---- Write src\CodeData.ahk ----
salt1Hex := Format("0x{:02X}{:02X}{:02X}{:02X}",
    NumGet(salt1, 0, "UChar"),
    NumGet(salt1, 1, "UChar"),
    NumGet(salt1, 2, "UChar"),
    NumGet(salt1, 3, "UChar"))

codeDataContent := "; ============================================================`n"
codeDataContent .= ";  src\CodeData.ahk  —  AUTO-GENERATED, DO NOT EDIT`n"
codeDataContent .= ";  Generated: " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`n"
codeDataContent .= ";  This file is in .gitignore — never commit it!`n"
codeDataContent .= "; ============================================================`n"
codeDataContent .= "`n"
codeDataContent .= "global CODES_SALT1 := " salt1Hex "`n"
codeDataContent .= "global CODES_DATA  := `"" b64 "`"`n"

cdFile := FileOpen(CODEDATA, "w")
if (!cdFile) {
    MsgBox("Failed to write src\CodeData.ahk!`nPath: " CODEDATA, "Error", 16)
    ExitApp()
}
cdFile.Write(codeDataContent)
cdFile.Close()

MsgBox(
    "Done!`n`n" .
    CODE_COUNT " codes generated.`n`n" .
    "codes.txt   → distribute to users`n" .
    "src\CodeData.ahk → embedded in EXE (do NOT commit)`n",
    "Code Generator", 64
)
ExitApp()

; ============================================================
;  Base64 encoder (pure AHK v2)
; ============================================================
B64Encode(buf, byteLen) {
    chars := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    out := ""
    i := 0
    while (i < byteLen) {
        b0 := NumGet(buf, i,   "UChar")
        b1 := (i + 1 < byteLen) ? NumGet(buf, i + 1, "UChar") : 0
        b2 := (i + 2 < byteLen) ? NumGet(buf, i + 2, "UChar") : 0

        out .= SubStr(chars, (b0 >> 2) + 1, 1)
        out .= SubStr(chars, (((b0 & 0x3) << 4) | (b1 >> 4)) + 1, 1)
        out .= (i + 1 < byteLen) ? SubStr(chars, (((b1 & 0xF) << 2) | (b2 >> 6)) + 1, 1) : "="
        out .= (i + 2 < byteLen) ? SubStr(chars, (b2 & 0x3F) + 1, 1) : "="

        i += 3
    }
    return out
}
