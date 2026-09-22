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
        [string]$Language = "en"
    )
    
    $GridConfigName = $ConfigPrefix
    $Categories = @()
    
    # Load language file
    $LangPath = Join-Path $PSScriptRoot "..\Language\$Language.toml"
    $Translations = Read-KeyValueFile -Path $LangPath
    
    # Generate date-based name for first category in OS native language
    $Now = Get-Date
    $CultureCode = (Get-Culture).Name
    $Culture = [System.Globalization.CultureInfo]::GetCultureInfo($CultureCode)
    $DateStr = $Now.ToString("d MMMM, H:mm", $Culture)
    
    foreach ($Pos in 1..5) {
        $Info = $PositionFields[$Pos]
        $SortedHeroes = $Heroes | Where-Object { $_.($Info.Field) -gt 1000 } | Sort-Object { $_.($Info.Field) } -Descending
        $TopHeroes = $SortedHeroes | Select-Object -First $MaxHeroes
        
        $TopIds = @($TopHeroes.id)
        
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
