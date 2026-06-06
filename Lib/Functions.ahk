global settingsFile := "" 
global confirmClicked := false


setupFilePath() {
    global settingsFile
    
    if !DirExist(A_ScriptDir "\Settings") {
        DirCreate(A_ScriptDir "\Settings")
    }

    settingsFile := A_ScriptDir "\Settings\Configuration.txt"
    return settingsFile
}

readInSettings() {
    global ZA_Q_En, ZA_Q_Key, ZA_Q_Int
    global ZA_E_En, ZA_E_Key, ZA_E_Int
    global ZA_R_En, ZA_R_Key, ZA_R_Int
    global ZA_Aim_En, ZA_Aim_Int
    global ZA_Atk_En, ZA_Atk_Int
    global ZA_PA_En,  ZA_PA_Int
    global ZA_DiffDD

    try {
        settingsFile := setupFilePath()
        if !FileExist(settingsFile)
            return

        content := FileRead(settingsFile)
        for line in StrSplit(content, "`n") {
            if (line = "")
                continue
            parts := StrSplit(line, "=", , 2)
            if (parts.Length < 2)
                continue
            switch parts[1] {
                case "ZA_Difficulty":   try ZA_DiffDD.Value  := (parts[2] = "Hardcore") ? 2 : 1
                case "ZA_Q_Enabled":    try ZA_Q_En.Value    := Integer(parts[2])
                case "ZA_Q_Key":        try ZA_Q_Key.Value   := parts[2]
                case "ZA_Q_Interval":   try ZA_Q_Int.Value   := parts[2]
                case "ZA_E_Enabled":    try ZA_E_En.Value    := Integer(parts[2])
                case "ZA_E_Key":        try ZA_E_Key.Value   := parts[2]
                case "ZA_E_Interval":   try ZA_E_Int.Value   := parts[2]
                case "ZA_R_Enabled":    try ZA_R_En.Value    := Integer(parts[2])
                case "ZA_R_Key":        try ZA_R_Key.Value   := parts[2]
                case "ZA_R_Interval":   try ZA_R_Int.Value   := parts[2]
                case "ZA_Aim_Enabled":  try ZA_Aim_En.Value  := Integer(parts[2])
                case "ZA_Aim_Interval": try ZA_Aim_Int.Value := parts[2]
                case "ZA_Atk_Enabled":  try ZA_Atk_En.Value  := Integer(parts[2])
                case "ZA_Atk_Interval": try ZA_Atk_Int.Value := parts[2]
                case "ZA_PA_Enabled":   try ZA_PA_En.Value   := Integer(parts[2])
                case "ZA_PA_Interval":  try ZA_PA_Int.Value  := parts[2]
            }
        }
        ProcessLog("Configuration settings loaded successfully")
    }
}


SaveSettings(*) {
    global ZA_Q_En, ZA_Q_Key, ZA_Q_Int
    global ZA_E_En, ZA_E_Key, ZA_E_Int
    global ZA_R_En, ZA_R_Key, ZA_R_Int
    global ZA_Aim_En, ZA_Aim_Int
    global ZA_Atk_En, ZA_Atk_Int
    global ZA_PA_En,  ZA_PA_Int
    global ZA_DiffDD, ZA_MapDD

    try {
        settingsFile := A_ScriptDir "\Settings\Configuration.txt"
        if FileExist(settingsFile)
            FileDelete(settingsFile)

        diff := (ZA_DiffDD.Value = 2) ? "Hardcore" : "Normal"
        map  := ZA_MapDD.Text

        content := "ZA_Map="         map  "`n"
        content .= "ZA_Difficulty="  diff "`n"
        content .= "ZA_Q_Enabled="   ZA_Q_En.Value    "`n"
        content .= "ZA_Q_Key="       ZA_Q_Key.Value   "`n"
        content .= "ZA_Q_Interval="  ZA_Q_Int.Value   "`n"
        content .= "ZA_E_Enabled="   ZA_E_En.Value    "`n"
        content .= "ZA_E_Key="       ZA_E_Key.Value   "`n"
        content .= "ZA_E_Interval="  ZA_E_Int.Value   "`n"
        content .= "ZA_R_Enabled="   ZA_R_En.Value    "`n"
        content .= "ZA_R_Key="       ZA_R_Key.Value   "`n"
        content .= "ZA_R_Interval="  ZA_R_Int.Value   "`n"
        content .= "ZA_Aim_Enabled=" ZA_Aim_En.Value  "`n"
        content .= "ZA_Aim_Interval=" ZA_Aim_Int.Value "`n"
        content .= "ZA_Atk_Enabled=" ZA_Atk_En.Value  "`n"
        content .= "ZA_Atk_Interval=" ZA_Atk_Int.Value "`n"
        content .= "ZA_PA_Enabled="  ZA_PA_En.Value   "`n"
        content .= "ZA_PA_Interval=" ZA_PA_Int.Value  "`n"

        FileAppend(content, settingsFile)
        ProcessLog("Configuration saved successfully")
    }
}


LoadSettings() {
    global UnitData, mode
    try {
        settingsFile := A_ScriptDir "\Settings\Configuration.txt"
        if !FileExist(settingsFile) {
            return
        }

        content := FileRead(settingsFile)
        sections := StrSplit(content, "`n`n")
        
        for section in sections {
            if (InStr(section, "Index=")) {
                lines := StrSplit(section, "`n")
                index := ""
                
                for line in lines {
                    if line = "" {
                        continue
                    }
                    
                    parts := StrSplit(line, "=")
                    if (parts[1] = "Index") {
                        index := parts[2]
                    } else if (index && UnitData.Has(Integer(index))) {
                        switch parts[1] {
                            case "Enabled": UnitData[index].Enabled.Value := parts[2]
                            case "Placement": UnitData[index].PlacementBox.Value := parts[2]
                        }
                    }
                }
            }
        }
        ProcessLog("Auto settings loaded successfully")
    }
}

CheckBanner(unitName) {

    ; First check if Roblox window exists
    if !WinExist(rblxID) {
        ProcessLog("Roblox window not found - skipping banner check")
        return false
    }

    ; Get Roblox window position
    WinGetPos(&robloxX, &robloxY, &rblxW, &rblxH, rblxID)
    
    detectionCount := 0
    ProcessLog("Checking for: " unitName)

    ; Split unit name into individual words
    unitName := Trim(unitName)  ; Remove spaces
    unitWords := StrSplit(unitName, " ")

    Loop 5 {
        try {
            result := OCR.FromRect(robloxX + 280, robloxY + 293, 250, 55, "en",
                {   
                    grayscale: true,
                    scale: 2.0
                })
            
            ; Check if all words are found in the text
            allWordsFound := true
            for word in unitWords {
                if !InStr(result.Text, word) {
                    allWordsFound := false
                    break
                }
            }
            
            if (allWordsFound) {
                detectionCount++
                Sleep(100)
            }
        }
    }

    if (detectionCount >= 1) {
        ProcessLog("Found " unitName " in banner")
        try {
            BannerFound()
        }
        return true
    }

    ProcessLog("Did not find " unitName " in banner")
    return false
}

SaveBannerSettings(*) {
    ProcessLog("Saving Banner Configuration")
    
    if FileExist("Settings\BannerUnit.txt")
        FileDelete("Settings\BannerUnit.txt")
    
    FileAppend(BannerUnitBox.Value, "Settings\BannerUnit.txt", "UTF-8")
}

SavePsSettings(*) {
    ProcessLog("Saving Private Server")
    
    if FileExist("Settings\PrivateServer.txt")
        FileDelete("Settings\PrivateServer.txt")
    
    FileAppend(PsLinkBox.Value, "Settings\PrivateServer.txt", "UTF-8")
}

SaveUINavSettings(*) {
    ProcessLog("Saving UI Navigation Key")
    
    if FileExist("Settings\UINavigation.txt")
        FileDelete("Settings\UINavigation.txt")
    
    FileAppend(UINavBox.Value, "Settings\UINavigation.txt", "UTF-8")
}

;Opens discord Link
OpenDiscordLink() {
    Run("https://discord.gg/mistdomain")
 }
 
 ;Minimizes the UI
 minimizeUI(*){
    aaMainUI.Minimize()
 }
 
 Destroy(*){
    aaMainUI.Destroy()
    ExitApp
 }
 ;Login Text
 setupOutputFile() {
     content := "`n==" aaTitle "" version "==`n  Start Time: [" currentTime "]`n"
     FileAppend(content, currentOutputFile)
 }
 
 ;Gets the current time
 getCurrentTime() {
     currentHour := A_Hour
     currentMinute := A_Min
     currentSecond := A_Sec
 
     return Format("{:d}h.{:02}m.{:02}s", currentHour, currentMinute, currentSecond)
 }



 OnModeChange(*) {
    global mode
    selected := ModeDropdown.Text
    
    ; Hide all dropdowns first
    StoryDropdown.Visible := false
    StoryActDropdown.Visible := false
    LegendDropDown.Visible := false
    LegendActDropdown.Visible := false
    RaidDropdown.Visible := false
    RaidActDropdown.Visible := false
    InfinityCastleDropdown.Visible := false
    MatchMaking.Visible := false
    ReturnLobbyBox.Visible := false
    ContractPageDropdown.Visible := false  
    ContractJoinDropdown.Visible := false 
    
    if (selected = "Story") {
        StoryDropdown.Visible := true
        StoryActDropdown.Visible := true
        mode := "Story"
    } else if (selected = "Legend") {
        LegendDropDown.Visible := true
        LegendActDropdown.Visible := true
        mode := "Legend"
    } else if (selected = "Raid") {
        RaidDropdown.Visible := true
        RaidActDropdown.Visible := true
        mode := "Raid"
    } else if (selected = "Infinity Castle") {
        InfinityCastleDropdown.Visible := true
        mode := "Infinity Castle"
    } else if (selected = "Contract") {
        ContractPageDropdown.Visible := true
        ContractJoinDropdown.Visible := true
        mode := "Contract"
    }
}

OnStoryChange(*) {
    if (StoryDropdown.Text != "") {
        StoryActDropdown.Visible := true
    } else {
        StoryActDropdown.Visible := false
    }
}

OnLegendChange(*) {
    if (LegendDropDown.Text != "") {
        LegendActDropdown.Visible := true
    } else {
        LegendActDropdown.Visible := false
    }
}

OnRaidChange(*) {
    if (RaidDropdown.Text != "") {
        RaidActDropdown.Visible := true
    } else {
        RaidActDropdown.Visible := false
    }
}

OnConfirmClick(*) {
    global ZA_MapDD, ZA_DiffDD

    map  := ZA_MapDD.Text
    diff := (ZA_DiffDD.Value = 2) ? "Hardcore" : "Normal"

    ; Save all UI settings to disk
    SaveSettings()

    ; Apply settings into the farm module globals
    try ZA_ApplyConfig()

    ProcessLog("✔ Config confirmed: " map " / " diff)
    ProcessLog("Press F2 to start the farm.")
    global confirmClicked := true
}


FixClick(x, y, LR := "Left") {
    MouseMove(x, y)
    MouseMove(1, 0, , "R")
    MouseClick(LR, -1, 0, , , , "R")
    Sleep(50)
}
 
CaptchaDetect(x, y, w, h, inputX, inputY) {
    detectionCount := 0
    ProcessLog("Checking for numbers...")
    Loop 10 {
        try {
            result := OCR.FromRect(x, y, w, h, "FirstFromAvailableLanguages", 
                {   
                    grayscale: true,
                    scale: 2.0
                })
            
            if result {
                ; Get text before any linebreak
                number := StrSplit(result.Text, "`n")[1]
                
                ; Clean to just get numbers
                number := RegExReplace(number, "[^\d]")
                
                if (StrLen(number) >= 5 && StrLen(number) <= 7) {
                    detectionCount++
                    
                    if (detectionCount >= 1) {
                        ; Send exactly what we detected in the green text
                        FixClick(inputX, inputY)
                        Sleep(300)
                        
                        ProcessLog("Sending number: " number)
                        for digit in StrSplit(number) {
                            Send(digit)
                            Sleep(120)
                        }
                        Sleep(200)
                        return true
                    }
                }
            }
        }
        Sleep(200)  
    }
    ProcessLog("Could not detect valid captcha")
    return false
}

; TogglePriorityDropdowns — no-op stub (priority dropdowns removed from ZA UI)
TogglePriorityDropdowns(*) {
}
