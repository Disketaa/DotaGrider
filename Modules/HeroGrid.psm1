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
        [string]$ConfigPrefix
    )
    
    $GridConfigName = "$ConfigPrefix - $(Get-Date -Format 'MMMM d, yyyy')"
    $Categories = @()
    
    foreach ($Pos in 1..5) {
        $Info = $PositionFields[$Pos]
        $SortedHeroes = $Heroes | Where-Object { $_.($Info.Field) -gt 1000 } | Sort-Object { $_.($Info.Field) } -Descending
        $TopHeroes = $SortedHeroes | Select-Object -First $MaxHeroes
        
        $TopIds = @($TopHeroes.id)
        
        $Categories += [PSCustomObject]@{
            category_name = "$($Info.Name) Top"
            x_position = 0
            y_position = ($Pos - 1) * $YOffset
            width = $Width
            height = $Height
            hero_ids = $TopIds
        }
    }
    
    return [PSCustomObject]@{
        version = 3
        configs = @(
            [PSCustomObject]@{
                config_name = "$GridConfigName - Top Heroes"
                categories = $Categories
            }
        )
    }
}

Export-ModuleMember -Function New-HeroGridConfig
