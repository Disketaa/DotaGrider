[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function New-EmptyRoleGrid {
    [CmdletBinding()]
    param(
        [int]$YOffset,
        [int]$Y,
        [int]$XOffset = -50,
        [string]$ConfigPrefix
    )
    
    $Categories = @()
    
    foreach ($Pos in 1..5) {
        $Categories += [PSCustomObject]@{
            category_name = "$Pos|"
            x_position = $XOffset
            y_position = $(if ($Pos -eq 1) { $Y } else { ($Pos - 1) * $YOffset })
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

Export-ModuleMember -Function New-EmptyRoleGrid
