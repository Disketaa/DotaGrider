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
        [string]$WinrateSeparator = " "
    )
    
    $Categories = @()
    
    foreach ($Pos in 1..5) {
        $Info = $PositionFields[$Pos]
        $Field = $Info.Field
        $WinField = $Field -replace "_match$", "_win"
        
        $HeroesWithData = $Heroes | Where-Object { $_.($Field) -gt 0 } | Sort-Object { $_.($Field) } -Descending
        $TopHeroes = $HeroesWithData | Select-Object -First $Count
        
        $WinrateStrings = @()
        foreach ($hero in $TopHeroes) {
            $matches = $hero.($Field)
            $wins = $hero.($WinField)
            $wr = if ($matches -gt 0) { [math]::Round(($wins / $matches) * 100) } else { 0 }
            $WinrateStrings += "$wr%"
        }
        
        while ($WinrateStrings.Count -lt $Count) {
            $WinrateStrings += "0%"
        }
        
        $CategoryName = $WinrateStrings -join $WinrateSeparator
        
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
