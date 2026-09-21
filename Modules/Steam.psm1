[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Get-ActiveSteamUserId {
    [CmdletBinding()]
    param(
        [string]$SteamConfigPath
    )
    
    if (-not (Test-Path $SteamConfigPath)) {
        return $null
    }
    
    $content = Get-Content $SteamConfigPath -Raw
    $activeUserId64 = $null
    $currentUser = $null
    $lines = $content -split "`r?`n"
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()
        if ($line -match '^"(\d+)"$') {
            $currentUser = $matches[1]
        }
        if ($currentUser -and $line -match '^"AutoLogin"\s+"(\d+)"$') {
            if ($matches[1] -eq '1') {
                $activeUserId64 = $currentUser
                break
            }
        }
    }
    
    # Convert SteamID64 to SteamID32 (used in userdata folder names)
    if ($activeUserId64) {
        $steamId64 = [long]$activeUserId64
        $steamId32 = $steamId64 - 76561197960265728
        return $steamId32.ToString()
    }
    
    return $null
}

function Get-SteamUserdataFolders {
    [CmdletBinding()]
    param(
        [string]$SteamUserdataPath,
        [string]$ActiveUserId
    )
    
    if ($ActiveUserId) {
        $folder = Get-ChildItem -Path $SteamUserdataPath -Directory | Where-Object { $_.Name -eq $ActiveUserId }
        if ($folder) {
            return @($folder)
        }
        throw "Active user folder '$ActiveUserId' not found under $SteamUserdataPath"
    }
    
    return Get-ChildItem -Path $SteamUserdataPath -Directory | Where-Object { $_.Name -match '^\d+$' }
}

Export-ModuleMember -Function Get-ActiveSteamUserId, Get-SteamUserdataFolders
