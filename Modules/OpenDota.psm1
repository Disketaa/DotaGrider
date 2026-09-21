[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Get-OpenDotaHeroStats {
    [CmdletBinding()]
    param(
        [string]$BaseUrl
    )
    
    Write-Host "Fetching hero stats from OpenDota..."
    $uri = "$BaseUrl/heroStats"
    $Heroes = Invoke-RestMethod -Uri $uri -Method Get
    
    if (-not $Heroes -or $Heroes.Count -eq 0) {
        throw "No hero data returned from OpenDota"
    }
    
    Write-Host "Fetched $($Heroes.Count) heroes from OpenDota"
    return $Heroes
}

Export-ModuleMember -Function Get-OpenDotaHeroStats
