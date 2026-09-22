[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Get-OpenDotaMatches {
    [CmdletBinding()]
    param(
        [string]$AccountId,
        [int]$Limit = 100
    )
    
    if (-not $AccountId) {
        throw "OpenDota account_id is required. Add it to Settings.toml under [opendota]."
    }
    
    # Extract numeric ID from URL if needed (supports /players/{id} and /profiles/{id64})
    $numericId = $AccountId
    if ($AccountId -match '/(\d+)$') {
        $numericId = $matches[1]
    } elseif ($AccountId -match '/(\d+)/?$') {
        $numericId = $matches[1]
    }
    
    Write-Host "Fetching last $Limit matches from OpenDota..."
    
    $url = "https://api.opendota.com/api/players/$numericId/matches?limit=$Limit"
    
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        return $response
    }
    catch {
        throw "OpenDota API failed: $($_.Exception.Message)"
    }
}

function Get-OpenDotaMatchDetail {
    [CmdletBinding()]
    param(
        [string]$MatchId,
        [int]$RetryCount = 3,
        [int]$DelaySeconds = 0
    )
    
    if (-not $MatchId) {
        return $null
    }
    
    $url = "https://api.opendota.com/api/matches/$MatchId"
    
    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
            return $response
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            if ($statusCode -eq 429) {
                $wait = $DelaySeconds
                Write-Host "Rate limited on match $MatchId, waiting ${wait}s (attempt $attempt/$RetryCount)"
                Start-Sleep -Seconds $wait
                $DelaySeconds *= 2
            }
            else {
                return $null
            }
        }
    }
    
    return $null
}

function Get-HeroMap {
    [CmdletBinding()]
    param(
        [string]$CachePath = "$PSScriptRoot\..\Content\heroes.json"
    )
    
    # Use cache if fresh (less than 7 days old)
    if (Test-Path $CachePath) {
        $cacheFile = Get-Item $CachePath
        $age = (Get-Date) - $cacheFile.LastWriteTime
        if ($age.TotalDays -lt 7) {
            return Get-Content $CachePath -Encoding UTF8 | ConvertFrom-Json
        }
    }
    
    Write-Host "Fetching hero map..."
    
    try {
        $heroes = Invoke-RestMethod -Uri "https://api.opendota.com/api/heroes" -Method Get -ErrorAction Stop
        
        # Ensure cache directory exists
        $cacheDir = Split-Path $CachePath -Parent
        if (-not (Test-Path $cacheDir)) {
            New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        }
        
        $heroes | ConvertTo-Json -Depth 5 | Set-Content -Path $CachePath -Encoding UTF8
        
        return $heroes
    }
    catch {
        if (Test-Path $CachePath) {
            return Get-Content $CachePath -Encoding UTF8 | ConvertFrom-Json
        }
        throw "OpenDota hero map fetch failed and no cache available: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function Get-OpenDotaMatches, Get-OpenDotaMatchDetail, Get-HeroMap
