#Requires AutoHotkey v2.0
; ============================================================
;  lib\Updater.ahk
;  Checks for updates from a remote JSON file
; ============================================================

class AutoUpdater {
    ; URL to the version.json file. For example, a GitHub Gist raw URL or your own server.
    static VersionUrl := "https://raw.githubusercontent.com/username/RobloxAFKKeeper/main/version.json"
    
    static CheckForUpdates(currentVersion) {
        try {
            http := ComObject("WinHttp.WinHttpRequest.5.1")
            http.Open("GET", this.VersionUrl, true)
            http.Send()
            http.WaitForResponse()

            if (http.Status = 200) {
                response := http.ResponseText
                
                ; Simple JSON regex parsing
                if (RegExMatch(response, '"version"\s*:\s*"([^"]+)"', &matchVer)) {
                    latestVersion := matchVer[1]
                    
                    if (this.CompareVersions(latestVersion, currentVersion) > 0) {
                        if (RegExMatch(response, '"download_url"\s*:\s*"([^"]+)"', &matchUrl)) {
                            downloadUrl := matchUrl[1]
                            this.PromptUpdate(latestVersion, downloadUrl)
                        }
                    }
                }
            }
        } catch {
            ; Silent fail if no internet or server is down
        }
    }

    static CompareVersions(v1, v2) {
        v1 := StrReplace(v1, "v", "")
        v2 := StrReplace(v2, "v", "")
        v1Parts := StrSplit(v1, ".")
        v2Parts := StrSplit(v2, ".")
        
        maxParts := Max(v1Parts.Length, v2Parts.Length)
        
        Loop maxParts {
            p1 := (A_Index <= v1Parts.Length) ? Number(v1Parts[A_Index]) : 0
            p2 := (A_Index <= v2Parts.Length) ? Number(v2Parts[A_Index]) : 0
            
            if (p1 > p2)
                return 1
            if (p1 < p2)
                return -1
        }
        return 0
    }

    static PromptUpdate(latestVersion, downloadUrl) {
        res := MsgBox("Доступна новая версия: " latestVersion "`nХотите скачать её сейчас?", "Обновление Roblox AFK Keeper", 0x4 + 0x40)
        if (res = "Yes") {
            Run(downloadUrl)
        }
    }
}
