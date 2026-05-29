#Requires AutoHotkey v2.0
; ============================================================
;  tools\obfuscate.ahk
;  Simple obfuscator / minimizer for AHK v2
;  1. Strips comments
;  2. Renames critical functions (CheckActivation -> _0xA1B2)
; ============================================================

InFile := A_Args.Length >= 1 ? A_Args[1] : A_ScriptDir "\..\RobloxAFKKeeper.ahk"
OutDir := A_Args.Length >= 2 ? A_Args[2] : A_ScriptDir "\..\build_tmp"

if !DirExist(OutDir)
    DirCreate(OutDir)

; Список функций/переменных для переименования (простейшая обфускация)
Renames := Map(
    "CheckActivation", "_0xA1",
    "ValidateLicenseFile", "_0xA2",
    "DecodeCodesData", "_0xA3",
    "IsCodeInData", "_0xA4",
    "GetHWIDHash", "_0xA5"
)

ProcessFile(InFile, OutDir)

ProcessFile(srcPath, outFolder) {
    global Renames
    SplitPath(srcPath, &outDir, &outExt, &outNameNoExt, &outDrive)
    
    if !FileExist(srcPath)
        return
        
    content := FileRead(srcPath, "UTF-8")
    
    ; Удаляем однострочные комментарии (начинающиеся с ; или пробел+;)
    content := RegExReplace(content, "m`a)^\s*;.*$", "")
    content := RegExReplace(content, "m`a)\s+;.*$", "")
    
    ; Переименование критических функций
    for oldName, newName in Renames {
        content := RegExReplace(content, "\b" oldName "\b", newName)
    }
    
    ; Обработка #Include для обфускации всех файлов проекта
    pos := 1
    while (pos := RegExMatch(content, "i`a)^\s*#Include\s+(.+)$", &match, pos)) {
        incPath := Trim(match[1], " `t`"")
        fullIncPath := outDir "\" incPath
        if InStr(fullIncPath, "*i ")
            fullIncPath := StrReplace(fullIncPath, "*i ", "")
            
        SplitPath(fullIncPath, &incDir, &incExt, &incNameNoExt, &incDrive)
        
        targetIncDir := outFolder "\" StrReplace(incDir, outDir "\", "")
        if !DirExist(targetIncDir)
            DirCreate(targetIncDir)
            
        ProcessFile(fullIncPath, outFolder)
        pos += match.Len
    }
    
    ; Сохраняем обфусцированный файл
    relPath := StrReplace(srcPath, outDir "\", "")
    outFilePath := outFolder "\" outNameNoExt "." outExt
    
    try FileDelete(outFilePath)
    FileAppend(content, outFilePath, "UTF-8")
}

FileAppend("Обфускация завершена.`n", "*")
ExitApp(0)
