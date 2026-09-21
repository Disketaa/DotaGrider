[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# Import modules
Import-Module "$PSScriptRoot\Modules\Settings.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Steam.psm1" -Force
Import-Module "$PSScriptRoot\Modules\OpenDota.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Stratz.psm1" -Force
Import-Module "$PSScriptRoot\Modules\HeroGrid.psm1" -Force

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
            $result += ' '
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
$MaxHeroes = $Settings.grid.max_heroes
$Width = $Settings.grid.width
$Height = $Settings.grid.height
$YOffset = $Settings.grid.y_offset
$ConfigPrefix = $Settings.grid.config_prefix
$SteamPath = $Settings.steam.steam_path
$DotaAppId = $Settings.steam.dota_app_id
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
    $CfgPath = Join-Path $UserFolder.FullName "$DotaAppId\remote\cfg\$ConfigFileName"
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
    $NewCfgDir = Join-Path $FirstUser.FullName "$DotaAppId\remote\cfg"
    if (-not (Test-Path $NewCfgDir)) {
        New-Item -ItemType Directory -Path $NewCfgDir -Force | Out-Null
    }
    $TargetCfgPaths += Join-Path $NewCfgDir $ConfigFileName
}

# Fetch hero stats
$PositionFields = @{
    1 = @{ Name = "Carry"; Field = "1_pick" }
    2 = @{ Name = "Mid"; Field = "2_pick" }
    3 = @{ Name = "Offlane"; Field = "3_pick" }
    4 = @{ Name = "Support"; Field = "4_pick" }
    5 = @{ Name = "Hard Support"; Field = "5_pick" }
}

if ($ApiProvider -eq "stratz") {
    $StratzToken = $Settings.api.stratz_token
    $RawStats = Get-StratzHeroStats -Token $StratzToken
    
    # Transform Stratz data to match OpenDota format
    $Heroes = @{}
    foreach ($row in $RawStats) {
        $heroId = $row.heroId
        if (-not $Heroes[$heroId]) {
            $Heroes[$heroId] = [ordered]@{
                id = $heroId
                "1_pick" = 0
                "2_pick" = 0
                "3_pick" = 0
                "4_pick" = 0
                "5_pick" = 0
            }
        }
        $pos = $row.position
        if ($pos -match 'POSITION_(\d)') {
            $posNum = [int]$matches[1]
            $field = "${posNum}_pick"
            $Heroes[$heroId][$field] = $row.matchCount
        }
    }
    $Heroes = $Heroes.Values | ForEach-Object { [PSCustomObject]$_ }
}
else {
    $Heroes = Get-OpenDotaHeroStats -BaseUrl $Settings.api.opendota_url
}

# Generate grid configs
$TopConfig = New-HeroGridConfig -Heroes $Heroes -PositionFields $PositionFields -MaxHeroes $MaxHeroes -Width $Width -Height $Height -YOffset $YOffset -ConfigPrefix $ConfigPrefix

# Also generate "All Heroes" config
$AllCategories = @()
foreach ($Pos in 1..5) {
    $Info = $PositionFields[$Pos]
    $SortedHeroes = $Heroes | Where-Object { $_.($Info.Field) -gt 1000 } | Sort-Object { $_.($Info.Field) } -Descending
    $AllHeroes = $SortedHeroes
    $AllIds = @($AllHeroes.id)
    
    $AllCategories += [PSCustomObject]@{
        category_name = $Info.Name
        x_position = 0
        y_position = ($Pos - 1) * $YOffset
        width = $Width
        height = $Height
        hero_ids = $AllIds
    }
}

$AllConfig = [PSCustomObject]@{
    version = 3
    configs = @(
        [PSCustomObject]@{
            config_name = "$($TopConfig.configs[0].config_name) - All Heroes"
            categories = $AllCategories
        }
    )
}

# Merge and write configs
foreach ($ConfigPath in $TargetCfgPaths) {
    if (Test-Path $ConfigPath) {
        $ExistingConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    } else {
        $ExistingConfig = @{ version = 3; configs = @() }
    }

    $ExistingConfig.configs = @($ExistingConfig.configs + $TopConfig.configs + $AllConfig.configs)

    $UniqueConfigs = @{}
    foreach ($Config in $ExistingConfig.configs) {
        $UniqueConfigs[$Config.config_name] = $Config
    }
    $ExistingConfig.configs = $UniqueConfigs.Values | Sort-Object { $_.config_name }

    $json = $ExistingConfig | ConvertTo-Json -Depth 10 -Compress
    $formatted = Format-Json -Json $json
    [System.IO.File]::WriteAllText($ConfigPath, $formatted, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Updated: $ConfigPath"
}

Write-Host "Hero grid generation complete."
