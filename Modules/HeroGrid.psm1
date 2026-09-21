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
        [int]$InitialY,
        [string]$ConfigPrefix,
        [string]$Language = "en"
    )
    
    $GridConfigName = $ConfigPrefix
    $Categories = @()
    
    # Load language file
    $LangPath = Join-Path $PSScriptRoot "..\Content\Language\$Language.toml"
    $Translations = Read-KeyValueFile -Path $LangPath
    
    foreach ($Pos in 1..5) {
        $Info = $PositionFields[$Pos]
        $SortedHeroes = $Heroes | Where-Object { $_.($Info.Field) -gt 1000 } | Sort-Object { $_.($Info.Field) } -Descending
        $TopHeroes = $SortedHeroes | Select-Object -First $MaxHeroes
        
        $TopIds = @($TopHeroes.id)
        
        # Translate category name if available
        $CategoryName = $Info.Name
        if ($Translations.ContainsKey($CategoryName)) {
            $CategoryName = $Translations[$CategoryName]
        }
        
        $Categories += [PSCustomObject]@{
            category_name = $CategoryName
            x_position = 0
            y_position = $InitialY + ($Pos - 1) * $YOffset
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
