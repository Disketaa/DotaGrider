[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# Import modules
Import-Module "$PSScriptRoot\Modules\Settings.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Steam.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Stratz.psm1" -Force
Import-Module "$PSScriptRoot\Modules\HeroGrid.psm1" -Force
Import-Module "$PSScriptRoot\Modules\DecoGrid.psm1" -Force

function Format-Json {
    param([string]$Json)
    $indent = 0
    $result = ""
    $inString = $false
    $escape = $false
    for ($i = 0; $i -lt $Json.Length; $i++) {
        $ch = $Json[$i]
        if ($escape) {
            $result += $ch
            $escape = $false
            continue
        }
        if ($ch -eq '\\') {
            $result += $ch
            $escape = $true
            continue
        }
        if ($ch -eq '"') {
            $inString = -not $inString
            $result += $ch
            continue
        }
        if ($inString) {
            $result += $ch
            continue
        }
        if ($ch -eq '{' -or $ch -eq '[') {
            $nextNonWs = $i + 1
            while ($nextNonWs -lt $Json.Length -and $Json[$nextNonWs] -match '\s') {
                $nextNonWs++
            }
            $isEmpty = $nextNonWs -lt $Json.Length -and $Json[$nextNonWs] -eq $(if ($ch -eq '{') { '}' } else { ']' })
            
            if ($isEmpty) {
                $result += $ch
                $result += "`r`n"
                $result += '    ' * $indent
                $result += $(if ($ch -eq '[') { ']' } else { '}' })
                $i = $nextNonWs
                continue
            }
            
            $result += $ch
            $result += "`r`n"
            $indent++
            $result += '    ' * $indent
            continue
        }
        if ($ch -eq '}' -or $ch -eq ']') {
            $result += "`r`n"
            $indent--
            $result += '    ' * $indent
            $result += $ch
            continue
        }
        if ($ch -eq ',') {
            $result += $ch
            $result += "`r`n"
            $result += '    ' * $indent
            continue
        }
        if ($ch -eq ':') {
            $result += $ch
            $nextNonWs = $i + 1
            while ($nextNonWs -lt $Json.Length -and $Json[$nextNonWs] -match '\s') {
                $nextNonWs++
            }
            if ($nextNonWs -lt $Json.Length -and ($Json[$nextNonWs] -eq '[' -or $Json[$nextNonWs] -eq '{')) {
                $result += "`r`n"
                $result += '    ' * $indent
            } else {
                $result += ' '
            }
            continue
        }
        if ($ch -match '\s') {
            if ($result.Length -gt 0 -and $result[-1] -ne '`n' -and $result[-1] -ne '`r') {
                $result += ' '
            }
            continue
        }
        $result += $ch
    }
    return $result
}

# Load settings
$Settings = Read-Settings -Path "$PSScriptRoot\Content\Settings.toml"
$ApiProvider = $Settings.api.provider

# Stratz grid settings
$StratzGrid = $Settings.stratz_grid
$MaxHeroes = $StratzGrid.max_heroes
$Width = $StratzGrid.width
$Height = $StratzGrid.height
$YOffset = $StratzGrid.y_offset
$InitialY = $StratzGrid.y
$XOffset = $StratzGrid.x_offset
$ConfigPrefix = $StratzGrid.config_prefix
$Language = $Settings.language

# Winrate grid settings
$WinrateGrid = $Settings.winrate_grid
$WinrateSeparator = $WinrateGrid.separator
$WinrateXOffset = $WinrateGrid.x_offset
$WinrateYOffset = $WinrateGrid.y_offset
$WinrateY = $WinrateGrid.y

# Role grid settings
$RoleGrid = $Settings.role_grid
$RoleYOffset = $RoleGrid.y_offset
$RoleY = $RoleGrid.y
$RoleXOffset = $RoleGrid.x_offset
$SteamPath = $Settings.steam.steam_path
$ConfigFileName = "hero_grid_config.json"

Write-Host "=== DotaGrider ==="
Write-Host "API Provider: $ApiProvider"
Write-Host "Max heroes per category: $MaxHeroes"
Write-Host "Category size: ${Width}x${Height}, y-offset: $YOffset"

# Detect active Steam user
$SteamConfigPath = Join-Path $SteamPath "config\loginusers.vdf"
$ActiveUserId = Get-ActiveSteamUserId -SteamConfigPath $SteamConfigPath
$SteamUserdataPath = Join-Path $SteamPath "userdata"

$UserdataFolders = Get-SteamUserdataFolders -SteamUserdataPath $SteamUserdataPath -ActiveUserId $ActiveUserId

$TargetCfgPaths = @()
foreach ($UserFolder in $UserdataFolders) {
    $CfgPath = Join-Path $UserFolder.FullName "570\remote\cfg\$ConfigFileName"
    if (Test-Path $CfgPath) {
        $TargetCfgPaths += $CfgPath
    }
}

if (-not $TargetCfgPaths) {
    Write-Host "No existing hero_grid_config.json found. Will create new in first userdata folder."
    $FirstUser = $UserdataFolders | Select-Object -First 1
    if (-not $FirstUser) {
        Write-Host "No Steam userdata folders found."
        exit 1
    }
    $NewCfgDir = Join-Path $FirstUser.FullName "570\remote\cfg"
    if (-not (Test-Path $NewCfgDir)) {
        New-Item -ItemType Directory -Path $NewCfgDir -Force | Out-Null
    }
    $TargetCfgPaths += Join-Path $NewCfgDir $ConfigFileName
}

# Fetch hero stats
$PositionFields = @{
    1 = @{ Name = "Carry"; Field = "1_match" }
    2 = @{ Name = "Midlane"; Field = "2_match" }
    3 = @{ Name = "Offlane"; Field = "3_match" }
    4 = @{ Name = "Support"; Field = "4_match" }
    5 = @{ Name = "Hard Support"; Field = "5_match" }
}

$StratzToken = $Settings.api.stratz_token
$RawStats = Get-StratzHeroStats -Token $StratzToken

# Transform Stratz data to match internal format
$Heroes = @{}
foreach ($row in $RawStats) {
    $heroId = $row.heroId
    if (-not $Heroes[$heroId]) {
        $Heroes[$heroId] = [ordered]@{
            id = $heroId
            "1_match" = 0
            "1_win" = 0
            "2_match" = 0
            "2_win" = 0
            "3_match" = 0
            "3_win" = 0
            "4_match" = 0
            "4_win" = 0
            "5_match" = 0
            "5_win" = 0
        }
    }
    $pos = $row.position
    if ($pos -match 'POSITION_(\d)') {
        $posNum = [int]$matches[1]
        $matchField = "${posNum}_match"
        $winField = "${posNum}_win"
        $Heroes[$heroId][$matchField] = $row.matchCount
        $Heroes[$heroId][$winField] = $row.winCount
    }
}
$Heroes = $Heroes.Values | ForEach-Object { [PSCustomObject]$_ }

# Generate grid configs
$TopConfig = New-HeroGridConfig -Heroes $Heroes -PositionFields $PositionFields -MaxHeroes $MaxHeroes -Width $Width -Height $Height -YOffset $YOffset -Y $InitialY -XOffset $XOffset -ConfigPrefix $ConfigPrefix -Language $Language
$RoleCategories = New-DecoratorGrid -YOffset $RoleYOffset -Y $RoleY -Offset 0 -XOffset $RoleXOffset -ConfigPrefix "ROLES" -Heroes $Heroes -PositionFields $PositionFields -Count $MaxHeroes -WinrateSeparator $WinrateSeparator
$WinrateCategories = New-DecoratorGrid -YOffset $WinrateYOffset -Y $WinrateY -Offset 0 -XOffset $WinrateXOffset -ConfigPrefix "WINRATES" -Heroes $Heroes -PositionFields $PositionFields -Count $MaxHeroes -WinrateSeparator $WinrateSeparator

# Append categories to STRATZ config
$TopConfig.configs[0].categories += $RoleCategories.configs[0].categories
$TopConfig.configs[0].categories += $WinrateCategories.configs[0].categories

# Merge and write configs
foreach ($ConfigPath in $TargetCfgPaths) {
    if (Test-Path $ConfigPath) {
        $rawContent = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.UTF8Encoding]::new($false))
        if ($rawContent -and $rawContent.Trim()) {
            $ExistingConfig = $rawContent | ConvertFrom-Json
        } else {
            $ExistingConfig = $null
        }
    } else {
        $ExistingConfig = $null
    }

    if (-not $ExistingConfig) {
        $ExistingConfig = [PSCustomObject]@{ version = 3; configs = @() }
    }

    if (-not $ExistingConfig.PSObject.Properties['configs']) {
        $ExistingConfig | Add-Member -NotePropertyName configs -NotePropertyValue ([object[]]@())
    }

    # Replace existing STRATZ config
    $ExistingConfig.configs = @($ExistingConfig.configs | Where-Object { $_.config_name -ne $ConfigPrefix })
    $ExistingConfig.configs = @($ExistingConfig.configs) + @($TopConfig.configs)

    $json = $ExistingConfig | ConvertTo-Json -Depth 10 -Compress
    $formatted = Format-Json -Json $json
    [System.IO.File]::WriteAllText($ConfigPath, $formatted, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Updated: $ConfigPath"
}

Write-Host "Hero grid generation complete."
