; ============================================================
;  lib\Updater.ahk
;  Auto-updater via GitHub Releases API
;
;  Checks WildeSR98/afk for new releases, compares with
;  current APP_VERSION, offers download and self-replace.
;  Caches last check timestamp (24h cooldown).
; ============================================================

; --- Configuration ---
global UPDATER_REPO_OWNER := "WildeSR98"
global UPDATER_REPO_NAME  := "afk"
global UPDATER_API_URL    := "https://api.github.com/repos/" UPDATER_REPO_OWNER "/" UPDATER_REPO_NAME "/releases/latest"
global UPDATER_CHECK_INTERVAL := 86400  ; 24 hours in seconds
global UPDATER_CACHE_FILE     := A_ScriptDir "\resources\update_cache.ini"

; ============================================================
;  Check for updates (with 24h cache, silent=true skips UI if up-to-date)
; ============================================================
CheckForUpdates(silent := false) {
    global APP_VERSION, UPDATER_CACHE_FILE, UPDATER_CHECK_INTERVAL

    ; Check cache — skip if checked recently (only in silent mode)
    if (silent && FileExist(UPDATER_CACHE_FILE)) {
        try {
            lastCheck := IniRead(UPDATER_CACHE_FILE, "Update", "LastCheck", "0")
            if (lastCheck != "" && lastCheck != "0") {
                elapsed := A_Now
                elapsed := DateDiff(elapsed, lastCheck, "Seconds")
                if (elapsed < UPDATER_CHECK_INTERVAL) {
                    return  ; Already checked within 24h
                }
            }
        }
    }

    ; Save current check time
    try {
        if (!DirExist(A_ScriptDir "\resources"))
            DirCreate(A_ScriptDir "\resources")
        IniWrite(A_Now, UPDATER_CACHE_FILE, "Update", "LastCheck")
    }

    ; Fetch latest release from GitHub API
    releaseInfo := FetchLatestRelease()
    if (!releaseInfo) {
        if (!silent)
            MsgBox(L("UpdateCheckFailed"), L("UpdateTitle"), 48)
        return
    }

    latestTag     := releaseInfo.tag
    downloadUrl   := releaseInfo.downloadUrl
    releaseNotes  := releaseInfo.body

    ; Compare versions
    currentVer := VersionToNumber(APP_VERSION)
    latestVer  := VersionToNumber(latestTag)

    if (latestVer <= currentVer) {
        if (!silent)
            MsgBox(L("UpdateUpToDate") "`n`n" L("UpdateCurrentVer") ": " APP_VERSION, L("UpdateTitle"), 64)
        return
    }

    ; New version available — ask user
    msg := L("UpdateAvailable") "`n`n"
    msg .= L("UpdateCurrentVer") ": " APP_VERSION "`n"
    msg .= L("UpdateNewVer") ": " latestTag "`n"
    if (releaseNotes != "")
        msg .= "`n" releaseNotes

    result := MsgBox(msg, L("UpdateTitle"), 36)  ; Yes/No
    if (result = "Yes") {
        DownloadAndInstallUpdate(downloadUrl, latestTag)
    }
}

; ============================================================
;  Fetch latest release info from GitHub via PowerShell
;  (WinHTTP fails on TLS 1.2 on some systems)
; ============================================================
FetchLatestRelease() {
    global UPDATER_API_URL

    tempFile := A_Temp "\roblox_afk_release.json"
    if (FileExist(tempFile))
        FileDelete(tempFile)

    ; Build PowerShell command
    psCmd := "powershell -NoProfile -NonInteractive -Command "
        . Chr(34)
        . "try { $r = Invoke-WebRequest -Uri '" UPDATER_API_URL "'"
        . " -Headers @{'User-Agent'='RobloxAFKKeeper-Updater'}"
        . " -UseBasicParsing -TimeoutSec 10;"
        . " $r.Content | Out-File -Encoding utf8 '" tempFile "' }"
        . " catch { exit 1 }"
        . Chr(34)

    try {
        RunWait(psCmd,, "Hide")
    } catch {
        return false
    }

    if (!FileExist(tempFile))
        return false

    try {
        responseText := FileRead(tempFile, "UTF-8")
        FileDelete(tempFile)
    } catch {
        return false
    }

    if (responseText = "")
        return false

    ; Parse JSON
    tag         := ExtractJsonString(responseText, "tag_name")
    body        := ExtractJsonString(responseText, "body")

    if (tag = "")
        return false

    ; Find .exe download URL in assets
    downloadUrl := ""
    assetsPos := InStr(responseText, '"assets"', true)
    if (assetsPos > 0) {
        searchFrom := assetsPos
        Loop {
            urlPos := InStr(responseText, '"browser_download_url"', true, searchFrom)
            if (urlPos = 0)
                break
            url := ExtractJsonString(SubStr(responseText, urlPos), "browser_download_url")
            if (SubStr(url, -3) = ".exe") {
                downloadUrl := url
                break
            }
            searchFrom := urlPos + 30
        }
    }

    ; Fallback to releases page if no .exe asset
    if (downloadUrl = "")
        downloadUrl := "https://github.com/" UPDATER_REPO_OWNER "/" UPDATER_REPO_NAME "/releases/tag/" tag

    return {tag: tag, downloadUrl: downloadUrl, body: body}
}

; ============================================================
;  Download the EXE and self-replace
; ============================================================
DownloadAndInstallUpdate(downloadUrl, newTag) {
    ; If running as source script (not compiled EXE) — open browser
    if (!A_IsCompiled) {
        MsgBox("Auto-install works only for compiled EXE.`nOpening download page...", L("UpdateTitle"), 64)
        Run(downloadUrl)
        return
    }

    ; If URL is a release page (no .exe asset), just open browser
    if (SubStr(downloadUrl, -3) != ".exe") {
        Run(downloadUrl)
        return
    }

    tempDir  := A_Temp "\RobloxAFKKeeper_Update"
    tempFile := tempDir "\RobloxAFKKeeper_new.exe"

    try {
        if (!DirExist(tempDir))
            DirCreate(tempDir)
        if (FileExist(tempFile))
            FileDelete(tempFile)
    }

    LogMsg("Downloading update " newTag "...")

    ; Download via PowerShell (WinHTTP fails with TLS on this system)
    psCmd := "powershell -NoProfile -NonInteractive -Command "
        . Chr(34)
        . "try {"
        . " Invoke-WebRequest -Uri '" downloadUrl "'"
        . " -Headers @{'User-Agent'='RobloxAFKKeeper-Updater'}"
        . " -OutFile '" tempFile "' -UseBasicParsing -TimeoutSec 120"
        . " } catch { exit 1 }"
        . Chr(34)

    try {
        RunWait(psCmd,, "Hide")
    } catch as err {
        MsgBox(L("UpdateDownloadFailed") "`n" err.Message, L("UpdateTitle"), 16)
        return
    }

    if (!FileExist(tempFile)) {
        MsgBox(L("UpdateDownloadFailed"), L("UpdateTitle"), 16)
        return
    }

    LogMsg("Download complete. Installing...")

    ; currentExe = full path to THIS compiled EXE
    ; workDir    = directory containing the EXE (where resources\ lives)
    currentExe := A_ScriptFullPath
    workDir    := A_ScriptDir
    currentPID := DllCall("GetCurrentProcessId")
    batchFile  := tempDir "\update.bat"

    ; Batch waits for THIS exact PID to exit, then replaces EXE and restarts
    batchContent := "@echo off`r`n"
    batchContent .= "echo Waiting for Roblox AFK Keeper to close...`r`n"
    batchContent .= ":waitloop`r`n"
    batchContent .= "tasklist /FI " Chr(34) "PID eq " currentPID Chr(34) " 2>nul | find /i " Chr(34) "" currentPID "" Chr(34) " >nul`r`n"
    batchContent .= "if not errorlevel 1 (timeout /t 1 /nobreak >nul & goto waitloop)`r`n"
    batchContent .= "echo Copying new version...`r`n"
    batchContent .= 'copy /Y "' tempFile '" "' currentExe '"' "`r`n"
    batchContent .= "if errorlevel 1 (echo Copy failed! & pause & exit /b 1)`r`n"
    batchContent .= "echo Restarting...`r`n"
    batchContent .= 'start "" /D "' workDir '" "' currentExe '"' "`r`n"
    batchContent .= 'del "' tempFile '"' "`r`n"
    batchContent .= 'del "%~f0"' "`r`n"

    f := FileOpen(batchFile, "w")
    f.Write(batchContent)
    f.Close()

    ; Run the updater batch and exit THIS process
    Run(batchFile,, "Hide")
    ExitApp()
}

; ============================================================
;  Version comparison helper
;  Converts "v3.2" or "3.2.1" to a comparable number
; ============================================================
VersionToNumber(ver) {
    ver := RegExReplace(ver, "^v", "")  ; strip leading "v"
    parts := StrSplit(ver, ".")
    major := (parts.Length >= 1) ? Integer(parts[1]) : 0
    minor := (parts.Length >= 2) ? Integer(parts[2]) : 0
    patch := (parts.Length >= 3) ? Integer(parts[3]) : 0
    return major * 10000 + minor * 100 + patch
}

; ============================================================
;  Minimal JSON string extractor (no external deps)
; ============================================================
ExtractJsonString(json, key) {
    pattern := '"' key '"\s*:\s*"((?:[^"\\]|\\.)*)"'
    if (RegExMatch(json, pattern, &m))
        return StrReplace(StrReplace(m[1], "\n", "`n"), "\\", "\")
    return ""
}
