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
    $activeUserId = $null
    $currentUser = $null
    $lines = $content -split "`r?`n"
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()
        if ($line -match '^"(\d+)"$') {
            $currentUser = $matches[1]
        }
        if ($currentUser -and $line -eq '"AutoLogin"') {
            $nextLine = $lines[$i + 1].Trim()
            if ($nextLine -match '"\d+"') {
                $autoLoginValue = $matches[0].Trim('"')
                if ($autoLoginValue -eq "1") {
                    $activeUserId = $currentUser
                    break
                }
            }
        }
    }
    
    return $activeUserId
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
        Write-Host "Active user folder not found, falling back to all users."
    }
    
    return Get-ChildItem -Path $SteamUserdataPath -Directory | Where-Object { $_.Name -match '^\d+$' }
}

Export-ModuleMember -Function Get-ActiveSteamUserId, Get-SteamUserdataFolders
