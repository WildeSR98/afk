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
;  Fetch latest release info from GitHub
; ============================================================
FetchLatestRelease() {
    global UPDATER_API_URL

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", UPDATER_API_URL, true)
        whr.SetRequestHeader("User-Agent", "RobloxAFKKeeper-Updater")
        whr.SetRequestHeader("Accept", "application/vnd.github.v3+json")
        whr.Send()
        whr.WaitForResponse()

        if (whr.Status != 200)
            return false

        responseText := whr.ResponseText
    } catch {
        return false
    }

    ; Parse JSON manually (no external dependencies)
    tag := ExtractJsonString(responseText, "tag_name")
    body := ExtractJsonString(responseText, "body")
    
    ; Find .exe download URL in assets
    downloadUrl := ""
    assetsPos := InStr(responseText, '"assets"', true)
    if (assetsPos > 0) {
        ; Look for browser_download_url ending in .exe
        searchFrom := assetsPos
        Loop {
            urlPos := InStr(responseText, '"browser_download_url"', true, searchFrom)
            if (urlPos = 0)
                break
            url := ExtractJsonString(SubStr(responseText, urlPos), "browser_download_url")
            if (SubStr(url, -4) = ".exe") {
                downloadUrl := url
                break
            }
            searchFrom := urlPos + 30
        }
    }

    ; If no .exe asset found, construct a URL to the release page
    if (downloadUrl = "") {
        downloadUrl := "https://github.com/" UPDATER_REPO_OWNER "/" UPDATER_REPO_NAME "/releases/tag/" tag
    }

    return {tag: tag, downloadUrl: downloadUrl, body: body}
}

; ============================================================
;  Download the EXE and self-replace
; ============================================================
DownloadAndInstallUpdate(downloadUrl, newTag) {
    ; If URL is a release page (no .exe asset), just open browser
    if (SubStr(downloadUrl, -4) != ".exe") {
        Run(downloadUrl)
        return
    }

    tempDir  := A_Temp "\RobloxAFKKeeper_Update"
    tempFile := tempDir "\RobloxAFKKeeper_new.exe"

    try {
        if (!DirExist(tempDir))
            DirCreate(tempDir)

        ; Download with progress indication
        LogMsg("Downloading update " newTag "...")

        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", downloadUrl, true)
        whr.SetRequestHeader("User-Agent", "RobloxAFKKeeper-Updater")
        whr.Send()
        whr.WaitForResponse()

        if (whr.Status != 200) {
            MsgBox(L("UpdateDownloadFailed") "`nHTTP " whr.Status, L("UpdateTitle"), 16)
            return
        }

        ; Save binary response to file
        adoStream := ComObject("ADODB.Stream")
        adoStream.Type := 1  ; Binary
        adoStream.Open()
        adoStream.Write(whr.ResponseBody)
        adoStream.SaveToFile(tempFile, 2)  ; Overwrite
        adoStream.Close()

        LogMsg("Download complete. Installing...")

    } catch as err {
        MsgBox(L("UpdateDownloadFailed") "`n" err.Message, L("UpdateTitle"), 16)
        return
    }

    ; Create a batch script that waits for this process to exit,
    ; then replaces the EXE and restarts it
    currentExe := A_ScriptFullPath
    batchFile  := tempDir "\update.bat"
    
    batchContent := "@echo off`r`n"
    batchContent .= "echo Updating Roblox AFK Keeper...`r`n"
    batchContent .= "timeout /t 2 /nobreak > nul`r`n"
    batchContent .= 'copy /Y "' tempFile '" "' currentExe '"`r`n'
    batchContent .= 'start "" "' currentExe '"`r`n'
    batchContent .= 'del "' tempFile '"`r`n'
    batchContent .= 'del "%~f0"`r`n'  ; Self-delete batch file

    f := FileOpen(batchFile, "w")
    f.Write(batchContent)
    f.Close()

    ; Run the updater batch and exit
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
