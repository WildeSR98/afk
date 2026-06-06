#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Image.ahk
#Include GameMango.ahk
#Include Functions.ahk
#Include webhooksettings.ahk

; Basic Application Info

global aaTitle := "WSR_Zombie Arena "
global version := "v1.0"
global rblxID := "ahk_exe RobloxPlayerBeta.exe"
;Coordinate and Positioning Variables
global targetWidth := 816
global targetHeight := 638
global offsetX := -5
global offsetY := 1
global WM_SIZING := 0x0214
global WM_SIZE := 0x0005
global centerX := 408
global centerY := 320
global successfulCoordinates := []
;State Variables
global enabledUnits := Map()  
global placementValues := Map()  
;Statistics Tracking
global Wins := 0
global loss := 0
global mode := ""
global StartTime := A_TickCount
global currentTime := GetCurrentTime()
;Gui creation
global uiBorders := []
global uiBackgrounds := []
global uiTheme := []
global UnitData := []
global aaMainUI := Gui("+AlwaysOnTop -Caption")
global lastlog := ""
global aaMainUIHwnd := aaMainUI.Hwnd
;Theme colors
uiTheme.Push("0xffffff")  ; Header color
uiTheme.Push("0x33322c")  ; Background color
uiTheme.Push("0xffffff")    ; Border color
uiTheme.Push("0x3d3c35")  ; Accent color
uiTheme.Push("0x3d3c36")   ; Trans color
uiTheme.Push("000000")    ; Textbox color
uiTheme.Push("00ffb3") ; HighLight
;Logs/Save settings
global settingsGuiOpen := false
global SettingsGUI := ""
global currentOutputFile := A_ScriptDir "\Logs\LogFile.txt"
global WebhookURLFile := "Settings\WebhookURL.txt"
global DiscordUserIDFile := "Settings\DiscordUSERID.txt"
global SendActivityLogsFile := "Settings\SendActivityLogs.txt"

if !DirExist(A_ScriptDir "\Logs") {
    DirCreate(A_ScriptDir "\Logs")
}
if !DirExist(A_ScriptDir "\Settings") {
    DirCreate(A_ScriptDir "\Settings")
}

setupOutputFile()

;------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------
aaMainUI.BackColor := uiTheme[2]
global Webhookdiverter := aaMainUI.Add("Edit", "x0 y0 w1 h1 +Hidden", "") ; diversion
uiBorders.Push(aaMainUI.Add("Text", "x0 y0 w1364 h1 +Background" uiTheme[3]))  ;Top line
uiBorders.Push(aaMainUI.Add("Text", "x0 y0 w1 h630 +Background" uiTheme[3]))   ;Left line
uiBorders.Push(aaMainUI.Add("Text", "x1363 y0 w1 h630 +Background" uiTheme[3])) ;Right line
uiBackgrounds.Push(aaMainUI.Add("Text", "x3 y3 w1360 h27 +Background" uiTheme[2])) ;Title Top
uiBorders.Push(aaMainUI.Add("Text", "x0 y30 w1363 h1 +Background" uiTheme[3])) ;Title bottom
uiBorders.Push(aaMainUI.Add("Text", "x802 y30 w1 h600 +Background" uiTheme[3])) ;Roblox Right
uiBorders.Push(aaMainUI.Add("Text", "x803 y433 w560 h1 +Background" uiTheme[3])) ;Process Top
uiBorders.Push(aaMainUI.Add("Text", "x803 y461 w560 h1 +Background" uiTheme[3])) ;Process bottom
uiBorders.Push(aaMainUI.Add("Text", "x0 y630 w1364 h1 +Background" uiTheme[3], "")) ;Roblox bottom

global robloxHolder := aaMainUI.Add("Text", "x3 y33 w797 h597 +Background" uiTheme[5], "") ;Roblox window box
Global Discord := aaMainUI.Add("Picture", "x1255 y-4 w42 h42 +BackgroundTrans", Discord) ;Discord logo
Discord.OnEvent("Click", (*) => OpenDiscordLink()) ;Open discord
global exitButton := aaMainUI.Add("Picture", "x1330 y1 w32 h32 +BackgroundTrans", Exitbutton) ;Exit image
exitButton.OnEvent("Click", (*) => Destroy()) ;Exit button
global minimizeButton := aaMainUI.Add("Picture", "x1300 y3 w27 h27 +Background" uiTheme[2], Minimize) ;Minimize gui
minimizeButton.OnEvent("Click", (*) => minimizeUI()) ;Minimize gui
aaMainUI.SetFont("Bold s16 c" uiTheme[1], "Verdana") ;Font
global windowTitle := aaMainUI.Add("Text", "x10 y3 w1200 h29 +BackgroundTrans", aaTitle "" . "" version) ;Title
aaMainUI.Add("Text", "x805 y435 w558 h25 +Center +BackgroundTrans", "Process") ;Process header
aaMainUI.SetFont("norm s11 c" uiTheme[1]) ;Font
global process1 := aaMainUI.Add("Text", "x810 y470 w538 h18 +BackgroundTrans c" uiTheme[7], "➤ Created by Mist_Yuu (discord.gg/mistdomain)") ;Processes
global process2 := aaMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "") 
global process3 := aaMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "") 
global process4 := aaMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "") 
global process5 := aaMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "") 
global process6 := aaMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "") 
global process7 := aaMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "") 
WinSetTransColor(uiTheme[5], aaMainUI) ;Roblox window box

;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS
ShowSettingsGUI(*) {
    global settingsGuiOpen, SettingsGUI
    
    ; Check if settings window already exists
    if (SettingsGUI && WinExist("ahk_id " . SettingsGUI.Hwnd)) {
        WinActivate("ahk_id " . SettingsGUI.Hwnd)
        return
    }
    
    if (settingsGuiOpen) {
        return
    }
    
    settingsGuiOpen := true
    SettingsGUI := Gui("-MinimizeBox +Owner" aaMainUIHwnd)  
    SettingsGui.Title := "Settings"
    SettingsGUI.OnEvent("Close", OnSettingsGuiClose)
    SettingsGUI.BackColor := uiTheme[2]
    
    ; Window border
    SettingsGUI.Add("Text", "x0 y0 w1 h600 +Background" uiTheme[3])     ; Left
    SettingsGUI.Add("Text", "x599 y0 w1 h600 +Background" uiTheme[3])   ; Right
    SettingsGUI.Add("Text", "x0 y399 w600 h1 +Background" uiTheme[3])   ; Bottom
    
    ; Right side sections
    SettingsGUI.SetFont("s10", "Verdana")
    SettingsGUI.Add("GroupBox", "x310 y5 w280 h160 c" uiTheme[1], "Discord Webhook")  ; Box
    
    SettingsGUI.SetFont("s9", "Verdana")
    SettingsGUI.Add("Text", "x320 y30 c" uiTheme[1], "Webhook URL")     ; Webhook Text
    global WebhookURLBox := SettingsGUI.Add("Edit", "x320 y50 w260 h20 c" uiTheme[6])  ; Store webhook
    SettingsGUI.Add("Text", "x320 y83 c" uiTheme[1], "Discord ID (optional)")  ; Discord Id Text
    global DiscordUserIDBox := SettingsGUI.Add("Edit", "x320 y103 w260 h20 c" uiTheme[6])  ; Store Discord ID
    global SendActivityLogsBox := SettingsGUI.Add("Checkbox", "x320 y135 c" uiTheme[1], "Send Process")  ; Enable Activity

    ; Banner section
    SettingsGUI.Add("GroupBox", "x310 y175 w280 h100 c" uiTheme[1], "Banner Checker")  ; Box
    SettingsGUI.Add("Text", "x320 y195 c" uiTheme[1], "Banner Unit Name (Adding later)")  ; Banner Text
    global BannerUnitBox := SettingsGUI.Add("Edit", "x320 y215 w260 h20 c" uiTheme[6])  ; Store banner
    testBannerBtn := SettingsGUI.Add("Button", "x320 y240 w120 h25", "Test Banner")
    testBannerBtn.OnEvent("Click", (*) => CheckBanner(BannerUnitBox.Value))

    ; Private Server section
    SettingsGUI.Add("GroupBox", "x310 y280 w280 h100 c" uiTheme[1], "PS Link")  ; Box
    SettingsGUI.Add("Text", "x320 y300 c" uiTheme[1], "Private Server Link (optional)")  ; Ps text
    global PsLinkBox := SettingsGUI.Add("Edit", "x320 y320 w260 h20 c" uiTheme[6])  ;  ecit box

    SettingsGUI.Add("GroupBox", "x10 y10 w115 h70 c" uiTheme[1], "UI Navigation")
    SettingsGUI.Add("Text", "x20 y30 c" uiTheme[1], "Navigation Key")
    global UINavBox := SettingsGUI.Add("Edit", "x20 y50 w20 h20 c" uiTheme[6], "\")

    ; Save buttons
    webhookSaveBtn := SettingsGUI.Add("Button", "x460 y135 w120 h25", "Save Webhook")
    webhookSaveBtn.OnEvent("Click", (*) => SaveWebhookSettings())

    bannerSaveBtn := SettingsGUI.Add("Button", "x460 y240 w120 h25", "Save Banner")
    bannerSaveBtn.OnEvent("Click", (*) => SaveBannerSettings())

    PsSaveBtn := SettingsGUI.Add("Button", "x460 y345 w120 h25", "Save PsLink")
    PsSaveBtn.OnEvent("Click", (*) => SavePsSettings())

    UINavSaveBtn := SettingsGUI.Add("Button", "x50 y50 w60 h20", "Save")
    UINavSaveBtn.OnEvent("Click", (*) => SaveUINavSettings())

    ; Loadsettings
    if FileExist(WebhookURLFile)
        WebhookURLBox.Value := FileRead(WebhookURLFile, "UTF-8")
    if FileExist(DiscordUserIDFile)
        DiscordUserIDBox.Value := FileRead(DiscordUserIDFile, "UTF-8")
    if FileExist(SendActivityLogsFile)
        SendActivityLogsBox.Value := (FileRead(SendActivityLogsFile, "UTF-8") = "1")   
    if FileExist("Settings\BannerUnit.txt")
        BannerUnitBox.Value := FileRead("Settings\BannerUnit.txt", "UTF-8")
    if FileExist("Settings\PrivateServer.txt")
        PsLinkBox.Value := FileRead("Settings\PrivateServer.txt", "UTF-8")
    if FileExist("Settings\UINavigation.txt")
        UINavBox.Value := FileRead("Settings\UINavigation.txt", "UTF-8")

    ; Show the settings window
    SettingsGUI.Show("w600 h400")
    Webhookdiverter.Focus()
}

OpenGuide(*) {
    GuideGUI := Gui("+AlwaysOnTop")
    GuideGUI.SetFont("s10 bold", "Segoe UI")
    GuideGUI.Title := "Anime adventures settings (Thank you faxi)"

    GuideGUI.BackColor := "0c000a"
    GuideGUI.MarginX := 20
    GuideGUI.MarginY := 20

    ; Add Guide content
    GuideGUI.SetFont("s16 bold", "Segoe UI")

    GuideGUI.Add("Text", "x0 w800 cWhite +Center", "1 - In your AA settings make sure you have these 2 settings set to this")
    GuideGUI.Add("Picture", "x100 w600 h160 cWhite +Center", "Images\aasettings.png")

    GuideGUI.Add("Text", "x0 w800 cWhite +Center", "2 - In your ROBLOX settings, make sure your keyboard is set to click to move and your graphics are set to 1 and enable UI navigation")
    GuideGUI.Add("Picture", "x50 w700   cWhite +Center", "Images\Clicktomove.png")
    GuideGUI.Add("Picture", "x50 w700   cWhite +Center", "Images\graphics1.png")
    GuideGUI.Add("Text", "x0 w800 cWhite +Center", "3 - Set up the unit setup however you want, however I'd avoid hill only units       if you can since it might break")

    GuideGUI.Add("Text", "x0 w800 cWhite +Center", "4 - Rejoin Anime Adventures, dont move your camera at all and press F2 to start the macro. Good luck!" )

    GuideGUI.Show("w800")
}

aaMainUI.SetFont("s12 Bold c" uiTheme[1])
global settingsBtn := aaMainUI.Add("Button", "x1160 y0 w90 h30", "Settings")
settingsBtn.OnEvent("Click", ShowSettingsGUI)
global guideBtn := aaMainUI.Add("Button", "x1060 y0 w90 h30", "Guide")
guideBtn.OnEvent("Click", OpenGuide)

; ── Save Config bar ────────────────────────────────────────────────────────
aaMainUI.SetFont("s9 c" uiTheme[1])
aaMainUI.Add("Text",   "x810 y389 w80  h18 +BackgroundTrans", "Save Config")
placementSaveBtn := aaMainUI.Add("Button", "x810 y407 w80 h22", "Save")
placementSaveBtn.OnEvent("Click", SaveSettings)
aaMainUI.SetFont("s9 c" uiTheme[6])
aaMainUI.Add("Text", "x905 y389 w250 h16 +BackgroundTrans", "F1: Position Roblox")
aaMainUI.Add("Text", "x905 y407 w250 h16 +BackgroundTrans", "F2: Start  |  F3: Stop / Reload")

;--------------MODE SELECT────────────────────────────────────────────────────
global modeSelectionGroup := aaMainUI.Add("GroupBox", "x808 y38 w553 h45 Background" uiTheme[2], "Mode Select")
aaMainUI.SetFont("s10 c" uiTheme[6])
global ZA_ModeDD     := aaMainUI.Add("DropDownList", "x818  y53 w100 h80  Choose1 +Center", ["Play"])
global ZA_MapDD      := aaMainUI.Add("DropDownList", "x928  y53 w130 h80  Choose1 +Center", ["Rooftop Siege", "Atlantis"])
global ZA_DiffDD     := aaMainUI.Add("DropDownList", "x1068 y53 w110 h80  Choose1 +Center", ["Normal", "Hardcore", "Nightmare"])
global ZA_ConfirmBtn := aaMainUI.Add("Button",        "x1218 y53 w80  h25",                  "Confirm")
ZA_ConfirmBtn.OnEvent("Click", OnConfirmClick)

;------SKILL / ACTION CONFIGURATION────────────────────────────────────────────
; Helper: draws a card background row
ZA_AddCard(gui, y) {
    gui.Add("Text", Format("x808 y{} w553 h48 +Background{}", y,    uiTheme[4]))
    gui.Add("Text", Format("x808 y{} w553 h2  +Background{}", y,    uiTheme[3]))
    gui.Add("Text", Format("x808 y{} w553 h2  +Background{}", y+48, uiTheme[3]))
}

; Column X anchors
; chk=820  label=843  keyLbl=900  keyEdit=930  intLbl=980  intEdit=1060

; ── Skill 1 ─────────────────────────────────────────────────
ZA_AddCard(aaMainUI, 85)
aaMainUI.SetFont("s10 Bold c" uiTheme[1])
global ZA_Q_En  := aaMainUI.Add("CheckBox", "x820 y101 w16 h16 Checked", "")
aaMainUI.Add("Text", "x843 y99  w40 h20 +BackgroundTrans", "Skill")
aaMainUI.SetFont("s9 c" uiTheme[6])
aaMainUI.Add("Text", "x893 y101 w32 h16 +BackgroundTrans", "Key:")
global ZA_Q_Key := aaMainUI.Add("Edit", "x928 y99  w34 h20 +Center", "q")
aaMainUI.Add("Text", "x972 y101 w72 h16 +BackgroundTrans", "Interval (ms):")
global ZA_Q_Int := aaMainUI.Add("Edit", "x1048 y99 w80 h20 +Center", "5000")

; ── Skill 2 ─────────────────────────────────────────────────
ZA_AddCard(aaMainUI, 135)
aaMainUI.SetFont("s10 Bold c" uiTheme[1])
global ZA_E_En  := aaMainUI.Add("CheckBox", "x820 y151 w16 h16 Checked", "")
aaMainUI.Add("Text", "x843 y149 w40 h20 +BackgroundTrans", "Skill")
aaMainUI.SetFont("s9 c" uiTheme[6])
aaMainUI.Add("Text", "x893 y151 w32 h16 +BackgroundTrans", "Key:")
global ZA_E_Key := aaMainUI.Add("Edit", "x928 y149 w34 h20 +Center", "e")
aaMainUI.Add("Text", "x972 y151 w72 h16 +BackgroundTrans", "Interval (ms):")
global ZA_E_Int := aaMainUI.Add("Edit", "x1048 y149 w80 h20 +Center", "5000")

; ── Skill 3 ─────────────────────────────────────────────────
ZA_AddCard(aaMainUI, 185)
aaMainUI.SetFont("s10 Bold c" uiTheme[1])
global ZA_R_En  := aaMainUI.Add("CheckBox", "x820 y201 w16 h16 Checked", "")
aaMainUI.Add("Text", "x843 y199 w40 h20 +BackgroundTrans", "Skill")
aaMainUI.SetFont("s9 c" uiTheme[6])
aaMainUI.Add("Text", "x893 y201 w32 h16 +BackgroundTrans", "Key:")
global ZA_R_Key := aaMainUI.Add("Edit", "x928 y199 w34 h20 +Center", "r")
aaMainUI.Add("Text", "x972 y201 w72 h16 +BackgroundTrans", "Interval (ms):")
global ZA_R_Int := aaMainUI.Add("Edit", "x1048 y199 w80 h20 +Center", "5000")

; ── Auto-Aim ────────────────────────────────────────────────
ZA_AddCard(aaMainUI, 235)
aaMainUI.SetFont("s10 Bold c" uiTheme[1])
global ZA_Aim_En  := aaMainUI.Add("CheckBox", "x820 y251 w16 h16 Checked", "")
aaMainUI.Add("Text", "x843 y249 w90 h20 +BackgroundTrans", "Auto-Aim")
aaMainUI.SetFont("s9 c" uiTheme[6])
aaMainUI.Add("Text", "x972 y251 w72 h16 +BackgroundTrans", "Interval (ms):")
global ZA_Aim_Int := aaMainUI.Add("Edit", "x1048 y249 w80 h20 +Center", "600")

; ── Auto-Attack ─────────────────────────────────────────────
ZA_AddCard(aaMainUI, 285)
aaMainUI.SetFont("s10 Bold c" uiTheme[1])
global ZA_Atk_En  := aaMainUI.Add("CheckBox", "x820 y301 w16 h16 Checked", "")
aaMainUI.Add("Text", "x843 y299 w100 h20 +BackgroundTrans", "Auto-Attack")
aaMainUI.SetFont("s9 c" uiTheme[6])
aaMainUI.Add("Text", "x972 y301 w72 h16 +BackgroundTrans", "Interval (ms):")
global ZA_Atk_Int := aaMainUI.Add("Edit", "x1048 y299 w80 h20 +Center", "800")

; ── Play Again ──────────────────────────────────────────────
ZA_AddCard(aaMainUI, 335)
aaMainUI.SetFont("s10 Bold c" uiTheme[1])
global ZA_PA_En  := aaMainUI.Add("CheckBox", "x820 y351 w16 h16 Checked", "")
aaMainUI.Add("Text", "x843 y349 w160 h20 +BackgroundTrans", "Play Again (OCR)")
aaMainUI.SetFont("s9 c" uiTheme[6])
aaMainUI.Add("Text", "x972 y351 w72 h16 +BackgroundTrans", "Interval (ms):")
global ZA_PA_Int := aaMainUI.Add("Edit", "x1048 y349 w80 h20 +Center", "8000")

readInSettings()
aaMainUI.Show("w1366 h633")
WinMove(0, 0,,, "ahk_id " aaMainUIHwnd)
forceRobloxSize()  ; Initial force size and position
SetTimer(checkRobloxSize, 600000)  ; Check every 10 minutes
;------UNIT CONFIGURATION ;------UNIT CONFIGURATION ;------UNIT CONFIGURATION ;------UNIT CONFIGURATION ;------UNIT CONFIGURATION ;------UNIT CONFIGURATION ;------UNIT CONFIGURATION
;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS

;Process text
ProcessLog(current) { 
    global process1, process2, process3, process4, process5, process6, process7, currentOutputFile, lastlog

    ; Remove arrow from all lines first
    process7.Value := StrReplace(process6.Value, "➤ ", "")
    process6.Value := StrReplace(process5.Value, "➤ ", "")
    process5.Value := StrReplace(process4.Value, "➤ ", "")
    process4.Value := StrReplace(process3.Value, "➤ ", "")
    process3.Value := StrReplace(process2.Value, "➤ ", "")
    process2.Value := StrReplace(process1.Value, "➤ ", "")
    
    ; Add arrow only to newest process
    process1.Value := "➤ " . current
    
    elapsedTime := getElapsedTime()
    Sleep(50)
    FileAppend(current . " " . elapsedTime . "`n", currentOutputFile)

    ; Add webhook logging
    lastlog := current
    if FileExist("Settings\SendActivityLogs.txt") {
        SendActivityLogsStatus := FileRead("Settings\SendActivityLogs.txt", "UTF-8")
        if (SendActivityLogsStatus = "1") {
            WebhookLog()
        }
    }
}

;Timer
getElapsedTime() {
    global StartTime
    ElapsedTime := A_TickCount - StartTime
    Minutes := Mod(ElapsedTime // 60000, 60)  
    Seconds := Mod(ElapsedTime // 1000, 60)
    return Format("{:02}:{:02}", Minutes, Seconds)
}

;Basically the code to move roblox, below

sizeDown() {
    global rblxID
    
    if !WinExist(rblxID)
        return

    WinGetPos(&X, &Y, &OutWidth, &OutHeight, rblxID)
    
    ; Exit fullscreen if needed
    if (OutWidth >= A_ScreenWidth && OutHeight >= A_ScreenHeight) {
        Send "{F11}"
        Sleep(100)
    }

    ; Force the window size and retry if needed
    Loop 3 {
        WinMove(X, Y, targetWidth, targetHeight, rblxID)
        Sleep(100)
        WinGetPos(&X, &Y, &OutWidth, &OutHeight, rblxID)
        if (OutWidth == targetWidth && OutHeight == targetHeight)
            break
    }
}

moveRobloxWindow() {
    global aaMainUIHwnd, offsetX, offsetY, rblxID
    
    if !WinExist(rblxID) {
        ProcessLog("Waiting for Roblox window...")
        return
    }

    ; First ensure correct size
    sizeDown()
    
    ; Then move relative to main UI
    WinGetPos(&x, &y, &w, &h, aaMainUIHwnd)
    WinMove(x + offsetX, y + offsetY,,, rblxID)
    WinActivate(rblxID)
}

forceRobloxSize() {
    global rblxID
    
    if !WinExist(rblxID) {
        checkCount := 0
        While !WinExist(rblxID) {
            Sleep(5000)
            if(checkCount >= 5) {
                ProcessLog("Attempting to locate the Roblox window")
            } 
            checkCount += 1
            if (checkCount > 12) { ; Give up after 1 minute
                ProcessLog("Could not find Roblox window")
                return
            }
        }
        ProcessLog("Found Roblox window")
    }

    WinActivate(rblxID)
    sizeDown()
    moveRobloxWindow()
}
; Function to periodically check window size
checkRobloxSize() {
    global rblxID
    if WinExist(rblxID) {
        WinGetPos(&X, &Y, &OutWidth, &OutHeight, rblxID)
        if (OutWidth != targetWidth || OutHeight != targetHeight) {
            sizeDown()
            moveRobloxWindow()
        }
    }
}
;Basically the code to move roblox, Above

OnSettingsGuiClose(*) {
    global settingsGuiOpen, SettingsGUI
    settingsGuiOpen := false
    if SettingsGUI {
        SettingsGUI.Destroy()
        SettingsGUI := ""  ; Clear the GUI reference
    }
}

checkSizeTimer() {
    if (WinExist("ahk_exe RobloxPlayerBeta.exe")) {
        WinGetPos(&X, &Y, &OutWidth, &OutHeight, "ahk_exe RobloxPlayerBeta.exe")
        if (OutWidth != 816 || OutHeight != 638) {
            ProcessLog("Fixing Roblox window size")
            moveRobloxWindow()
        }
    }
}

