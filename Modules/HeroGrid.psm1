[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function New-HeroGridConfig {
    [CmdletBinding()]
    param(
        [array]$Heroes,
        [hashtable]$PositionFields,
        [int]$MaxHeroes,
        [int]$Width,
        [int]$Height,
        [int]$YOffset,
        [int]$Y,
        [int]$XOffset = 0,
        [string]$ConfigPrefix,
        [int]$PickRateMinimum = 0,
        [int]$MinMatches = 200
    )
    
    $GridConfigName = $ConfigPrefix
    $Categories = @()
    
    # Calculate total matches per hero across all positions for pick rate filtering
    $HeroTotals = @{}
    foreach ($Pos in 1..5) {
        $field = $PositionFields[$Pos].Field
        foreach ($hero in $Heroes) {
            $heroId = $hero.id
            if (-not $HeroTotals[$heroId]) {
                $HeroTotals[$heroId] = 0
            }
            $HeroTotals[$heroId] += $hero.$field
        }
    }
    
    # Generate date-based name for first category in OS native language
    $Now = Get-Date
    $CultureCode = (Get-Culture).Name
    $Culture = [System.Globalization.CultureInfo]::GetCultureInfo($CultureCode)
    $DateStr = $Now.ToString("d MMMM, H:mm", $Culture)
    
    foreach ($Pos in 1..5) {
        $Info = $PositionFields[$Pos]
        $Field = $Info.Field
        $WinField = $Field -replace "_match$", "_win"
        
        # Sort by winrate descending (min matches, min pick rate)
        $SortedHeroes = $Heroes | Where-Object { 
            $matchCount = $_.($Field)
            $passesMinMatches = $matchCount -gt $MinMatches
            $passesPickRate = $true
            if ($PickRateMinimum -gt 0) {
                $heroId = $_.id
                $heroTotal = $HeroTotals[$heroId]
                if ($heroTotal -gt 0) {
                    $pickRate = ($matchCount / $heroTotal) * 100
                    $passesPickRate = $pickRate -ge $PickRateMinimum
                } else {
                    $passesPickRate = $false
                }
            }
            $passesMinMatches -and $passesPickRate
        } | Sort-Object { 
            $matchCount = $_.($Field)
            $wins = $_.($WinField)
            if ($matchCount -gt 0) { ($wins / $matchCount) * 100 } else { 0 }
        } -Descending
        $TopHeroes = $SortedHeroes | Select-Object -First $MaxHeroes
        
        $TopIds = @($TopHeroes | ForEach-Object { $_.id })
        
        # First category = current date, others = empty
        if ($Pos -eq 1) {
            $CategoryName = $DateStr
        } else {
            $CategoryName = ""
        }
        
        $Categories += [PSCustomObject]@{
            category_name = $CategoryName
            x_position = $XOffset
            y_position = $(if ($Pos -eq 1) { $Y } else { ($Pos - 1) * $YOffset })
            width = $Width
            height = $Height
            hero_ids = $TopIds
        }
    }
    
    return [PSCustomObject]@{
        version = 3
        configs = @(
            [PSCustomObject]@{
                config_name = $GridConfigName
                categories = $Categories
            }
        )
    }
}

Export-ModuleMember -Function New-HeroGridConfig
