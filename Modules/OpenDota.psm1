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
    
    Write-Host "Fetching last $Limit matches from OpenDota (account: $numericId)..."
    
    $url = "https://api.opendota.com/api/players/$numericId/matches?limit=$Limit"
    
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        Write-Host "Fetched $($response.Count) matches from OpenDota"
        return $response
    }
    catch {
        throw "OpenDota API failed: $($_.Exception.Message)"
    }
}

function Get-HeroMap {
    [CmdletBinding()]
    param(
        [string]$CachePath = "$PSScriptRoot\..\Content\heroes.json"
    )
    
    $cacheFile = Resolve-Path $CachePath -ErrorAction SilentlyContinue
    
    # Use cache if fresh (less than 7 days old)
    if ($cacheFile) {
        $age = (Get-Date) - $cacheFile.LastWriteTime
        if ($age.TotalDays -lt 7) {
            Write-Host "Using cached hero map ($([math]::Floor($age.TotalDays)) days old)"
            return Get-Content $cacheFile.FullName -Encoding UTF8 | ConvertFrom-Json
        }
    }
    
    Write-Host "Fetching hero map from OpenDota..."
    
    try {
        $heroes = Invoke-RestMethod -Uri "https://api.opendota.com/api/heroes" -Method Get -ErrorAction Stop
        
        # Ensure cache directory exists
        $cacheDir = Split-Path $CachePath -Parent
        if (-not (Test-Path $cacheDir)) {
            New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        }
        
        $heroes | ConvertTo-Json -Depth 5 | Set-Content -Path $CachePath -Encoding UTF8
        Write-Host "Cached hero map to $CachePath"
        
        return $heroes
    }
    catch {
        if ($cacheFile) {
            Write-Host "Failed to fetch hero map, using stale cache"
            return Get-Content $cacheFile.FullName -Encoding UTF8 | ConvertFrom-Json
        }
        throw "OpenDota hero map fetch failed and no cache available: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function Get-OpenDotaMatches, Get-HeroMap
