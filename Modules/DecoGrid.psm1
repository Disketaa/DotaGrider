[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function New-DecoratorGrid {
    [CmdletBinding()]
    param(
        [int]$YOffset,
        [int]$Y,
        [int]$Offset = 0,
        [int]$XOffset = -50,
        [string]$ConfigPrefix,
        [array]$Heroes,
        [hashtable]$PositionFields,
        [int]$Count = 10,
        [string]$WinrateSeparator = " ",
        [switch]$RoleNumbers,
        [int]$PickRateMinimum = 0,
        [int]$MinMatches = 0
    )
    
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
    
    foreach ($Pos in 1..5) {
        if ($RoleNumbers) {
            $CategoryName = "$Pos|"
        } else {
            $Info = $PositionFields[$Pos]
            $Field = $Info.Field
            $WinField = $Field -replace "_match$", "_win"
            
            # Use same hero order as HeroGrid (sorted by winrate descending, filtered by pick rate)
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
            $TopHeroes = $SortedHeroes | Select-Object -First $Count
            
            $WinrateStrings = @()
            foreach ($hero in $TopHeroes) {
                $matchCount = $hero.($Field)
                $wins = $hero.($WinField)
                $wr = if ($matchCount -gt 0) { [math]::Round(($wins / $matchCount) * 100, 0) } else { 0 }
                $WinrateStrings += "$wr%"
            }
            

            
            $CategoryName = $WinrateStrings -join $WinrateSeparator
        }
        
        $Categories += [PSCustomObject]@{
            category_name = $CategoryName
            x_position = $XOffset
            y_position = $Y + ($Pos - 1) * $YOffset + $Offset
            width = 0
            height = 0
            hero_ids = @()
        }
    }
    
    return [PSCustomObject]@{
        version = 3
        configs = @(
            [PSCustomObject]@{
                config_name = $ConfigPrefix
                categories = $Categories
            }
        )
    }
}

Export-ModuleMember -Function New-DecoratorGrid
