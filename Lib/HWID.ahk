#Requires AutoHotkey v2.0

; ==============================================================================
;  HWID.ahk — Модуль привязки к оборудованию (HWID) и онлайн-лицензирования
; ==============================================================================

; Вставьте сюда URL вашего развернутого веб-приложения Google Apps Script
global LicenseServerURL := "https://script.google.com/macros/s/AKfycbxdGH4ydoOn9QVNRpQw1EYqpw_ED4pDFCROI5C44IofCAsBCt3mA67MqlwnFiYCdwHL/exec"

; Список доверенных HWID разработчиков (работают без проверки лицензии)
global DeveloperHWIDs := [
    "5176375A-CA1DD9D6" ; Ваш HWID разработчика
]

; --- Основные функции модуля ---

HashString(str) {
    hash1 := 5381
    hash2 := 7919
    loop Parse, str {
        char := Ord(A_LoopField)
        hash1 := ((hash1 << 5) + hash1) + char
        hash1 &= 0xFFFFFFFF
        hash2 := ((hash2 << 7) + hash2) ^ char
        hash2 &= 0xFFFFFFFF
    }
    return Format("{:08X}-{:08X}", hash1, hash2)
}

GetHWID() {
    try {
        objWMIService := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")

        uuid := ""
        for objItem in objWMIService.ExecQuery("Select * from Win32_ComputerSystemProduct") {
            uuid := objItem.UUID
            break
        }

        boardSerial := ""
        for objItem in objWMIService.ExecQuery("Select * from Win32_BaseBoard") {
            boardSerial := objItem.SerialNumber
            break
        }

        cpuID := ""
        for objItem in objWMIService.ExecQuery("Select * from Win32_Processor") {
            cpuID := objItem.ProcessorId
            break
        }

        rawHWID := uuid . "|" . boardSerial . "|" . cpuID
        rawHWID := StrReplace(rawHWID, " ")
        rawHWID := StrReplace(rawHWID, "`r")
        rawHWID := StrReplace(rawHWID, "`n")
        rawHWID := StrReplace(rawHWID, "`t")

        return HashString(rawHWID)
    } catch Error as err {
        return "ERROR_HWID"
    }
}

CheckLicense() {
    global LicenseServerURL
    global DeveloperHWIDs

    currentHWID := GetHWID()

    ; 1. Проверяем, является ли устройство разработчиком
    for devHWID in DeveloperHWIDs {
        if (currentHWID == devHWID) {
            return ; Разработчику проверка не нужна, запускаем скрипт сразу
        }
    }

    ; 2. Путь к файлу лицензии в AppData
    appDataDir := EnvGet("APPDATA") "\ZombieArena"
    licenseFile := appDataDir "\license.key"

    ; Проверим, существует ли папка, если нет - создадим её
    if !DirExist(appDataDir) {
        DirCreate(appDataDir)
    }

    ; 3. Проверка локальной лицензии
    if FileExist(licenseFile) {
        try {
            licenseContent := FileRead(licenseFile)
            parts := StrSplit(licenseContent, "|")
            if (parts.Length == 2) {
                savedKey := parts[1]
                savedSig := parts[2]

                expectedSig := HashString(savedKey . "|" . currentHWID . "|ZombieArenaSalt2026")
                if (savedSig == expectedSig) {
                    return ; Лицензия верна, запускаем скрипт
                }
            }
        }
    }

    ; 4. Если лицензия не найдена или неверна - запускаем GUI активации
    ShowActivationGUI(currentHWID, licenseFile)
}

ShowActivationGUI(currentHWID, licenseFile) {
    ; Копируем HWID в буфер обмена для удобства пользователя
    A_Clipboard := currentHWID

    MyGui := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", "Активация Zombie Arena")
    MyGui.SetFont("s10", "Segoe UI")

    MyGui.AddText("w320 Center", "Внимание: Требуется лицензионный ключ!")
    MyGui.AddText("w320 Center cGray s8", "Ваш HWID автоматически скопирован в буфер обмена")
    MyGui.AddText("w320 Center cGray s8", "HWID: " currentHWID)

    MyGui.AddText("w320 y+15", "Введите ваш 16-значный лицензионный ключ:")
    KeyEdit := MyGui.AddEdit("w320 Limit50")

    StatusText := MyGui.AddText("w320 cRed Center y+5", "")

    BtnActivate := MyGui.AddButton("w120 Default y+10 xp+100", "Активировать")
    BtnActivate.OnEvent("Click", (*) => AttemptActivation(MyGui, KeyEdit.Value, currentHWID, licenseFile, StatusText, BtnActivate))

    MyGui.OnEvent("Close", (*) => ExitApp())
    MyGui.Show("w350")

    ; Приостанавливаем выполнение основного скрипта, пока идет активация
    while WinExist("Активация Zombie Arena") {
        Sleep 250
    }
}

AttemptActivation(GuiObj, enteredKey, currentHWID, licenseFile, StatusText, BtnObj) {
    cleanKey := Trim(enteredKey)
    if (cleanKey == "") {
        StatusText.Text := "Ошибка: Введите ключ!"
        return
    }

    BtnObj.Enabled := false
    StatusText.Text := "Проверка ключа..."

    global LicenseServerURL
    if (LicenseServerURL == "https://script.google.com/macros/s/.../exec") {
        StatusText.Text := "Ошибка: Не настроен URL сервера лицензий!"
        BtnObj.Enabled := true
        return
    }

    ; Формируем URL
    url := LicenseServerURL "?key=" cleanKey "&hwid=" currentHWID

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", url, true)
        whr.Send()
        whr.WaitForResponse(10) ; Ждем до 10 секунд
        response := whr.ResponseText

        if InStr(response, "SUCCESS") {
            ; Активация успешна! Записываем локальную лицензию
            sig := HashString(cleanKey . "|" . currentHWID . "|ZombieArenaSalt2026")

            if FileExist(licenseFile)
                FileDelete(licenseFile)
            FileAppend(cleanKey . "|" . sig, licenseFile)

            MsgBox("Активация успешно завершена!", "Zombie Arena", "Icon* 64")
            GuiObj.Destroy()
        } else if InStr(response, "ERROR: Invalid key") {
            StatusText.Text := "Ошибка: Ключ не существует!"
            BtnObj.Enabled := true
        } else if InStr(response, "ERROR: Key already in use") {
            StatusText.Text := "Ошибка: Ключ уже активирован на другом ПК!"
            BtnObj.Enabled := true
        } else {
            StatusText.Text := "Ошибка сервера: " response
            BtnObj.Enabled := true
        }
    } catch Error as err {
        StatusText.Text := "Ошибка соединения с сервером!"
        BtnObj.Enabled := true
    }
}