[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# Import modules
Import-Module "$PSScriptRoot\Modules\Settings.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Steam.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Stratz.psm1" -Force
Import-Module "$PSScriptRoot\Modules\HeroGrid.psm1" -Force
Import-Module "$PSScriptRoot\Modules\DecoGrid.psm1" -Force

function Format-DotaNumbers {
    param([string]$Json)
    $invariant = [System.Globalization.CultureInfo]::InvariantCulture
    return [Regex]::Replace($Json, '("(?:x_position|y_position|width|height)"\s*:\s*)(\d+(?:\.\d+)?)', {
        param($m)
        $num = [double]$m.Groups[2].Value
        return "$($m.Groups[1].Value)$($num.ToString('F6', $invariant))"
    })
}

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
        if ($ch -eq '\') {
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
# Load settings or prompt for first-run setup

$SettingsPath = "$PSScriptRoot\Settings.toml"

if (-not (Test-Path $SettingsPath)) {
    Write-Host "=== First Run Setup ==="
    Write-Host "Settings.toml not found. Creating from template."
    
    $Token = Read-Host "Enter your Stratz API token (get one at https://stratz.com/api)"
    if ([string]::IsNullOrWhiteSpace($Token)) {
        Write-Host "Token is required. Exiting."
        exit 1
    }
    
    $AccountId = Read-Host "Enter your Steam account ID (32-bit, find it at https://www.stratz.com/player/YOUR_STEAM_ID)"
    
    $SettingsContent = @"
# DotaGrider Settings
language = "Russian"

[api]
provider = "stratz"
stratz_token = "$Token"
stratz_bracket = "DIVINE"
stratz_weeks_back = 1
stratz_account_id = "$AccountId"

[stratz_grid]
config_prefix = "STRATZ"
y = 0
x_offset = 20
y_offset = 110
width = 750
height = 100
max_heroes = 10

[recent_grid]
x_offset = 720
width = 750
max_heroes = 6

[role_grid]
y = 62
x_offset = 0
y_offset = 110

[winrate_grid]
separator = "    "
y = 115
x_offset = 34
y_offset = 110

[steam]
steam_path = "C:\\Program Files (x86)\\Steam"
"@
    Set-Content -Path $SettingsPath -Value $SettingsContent -Encoding UTF8
    Write-Host "Settings.toml created."
}
# Load settings

$SettingsPath = "$PSScriptRoot\Settings.toml"
$Settings = Read-Settings -Path $SettingsPath
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

# Load language translations
$LangPath = Join-Path $PSScriptRoot "Language\$Language.toml"
$Translations = Read-KeyValueFile -Path $LangPath
$RecentHeroesLabel = $Translations["Recent Heroes"]

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

# STRATZ account settings
$StratzAccountId = $Settings.api.stratz_account_id
$RecentMatchLimit = 20

# Recent grid settings
$RecentGrid = $Settings.recent_grid
$RecentXOffset = if ($RecentGrid -and $RecentGrid.x_offset) { [int]$RecentGrid.x_offset } else { 720 }
$RecentWidth = if ($RecentGrid -and $RecentGrid.width) { [int]$RecentGrid.width } else { 750 }
$RecentMaxHeroes = if ($RecentGrid -and $RecentGrid.max_heroes) { [int]$RecentGrid.max_heroes } else { 6 }
Write-Host "Recent grid settings: x_offset=$RecentXOffset width=$RecentWidth max_heroes=$RecentMaxHeroes"
Write-Host "Recent grid: x=$RecentXOffset width=$RecentWidth max=$RecentMaxHeroes"

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
$StratzBracket = $Settings.api.stratz_bracket
$StratzWeeksBack = $Settings.api.stratz_weeks_back
$RawStats = Get-StratzHeroStats -Token $StratzToken -Bracket $StratzBracket -WeeksBack $StratzWeeksBack

# Fetch current winrates from Stratz
$WinrateRows = Get-StratzHeroWinrate -Token $StratzToken -Bracket $StratzBracket
$HeroWinrates = @{}
foreach ($row in $WinrateRows) {
    if ($row.heroId -and $row.matchCount -gt 0) {
        $wrExact = ($row.winCount / $row.matchCount) * 100
        $HeroWinrates[$row.heroId] = [math]::Round($wrExact)
    }
}

# Transform Stratz data to match internal format
$Heroes = @{}
foreach ($row in $RawStats) {
    if ($row.matchCount -le 200) { continue }
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
            winrate = 0
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
# Set overall winrate from Stratz
foreach ($heroId in $Heroes.Keys) {
    if ($HeroWinrates[$heroId]) {
        $Heroes[$heroId].winrate = $HeroWinrates[$heroId]
    }
}
$Heroes = $Heroes.Values | ForEach-Object { [PSCustomObject]$_ }

# Build hero -> best position lookup from Stratz for fallback
$HeroBestPosition = @{}
foreach ($hero in $Heroes) {
    $bestPos = 1
    $bestMatches = 0
    foreach ($pos in 1..5) {
        $matchField = "${pos}_match"
        if ($hero.$matchField -gt $bestMatches) {
            $bestMatches = $hero.$matchField
            $bestPos = $pos
        }
    }
    $HeroBestPosition[$hero.id] = $bestPos
}

# Fetch recent match history from STRATZ
$RecentPositionCategories = @()
if ($StratzAccountId) {
    try {
        $Matches = Get-StratzPlayerMatches -Token $StratzToken -SteamAccountId $StratzAccountId -Take $RecentMatchLimit
        
        $LaneHeroes = @{}
        foreach ($match in $Matches) {
            if (-not $match.heroId -or -not $match.position) { continue }
            
            $heroId = [int]$match.heroId
            $position = $match.position
            
            # Normalize position to 1-5
            $posNum = $null
            if ($position -match 'POSITION_(\d)') {
                $posNum = [int]$matches[1]
            } elseif ($position -match '^\d$') {
                $posNum = [int]$position
            }
            if (-not $posNum -or $posNum -lt 1 -or $posNum -gt 5) { continue }
            
            if (-not $LaneHeroes[$posNum]) {
                $LaneHeroes[$posNum] = [System.Collections.Generic.List[int]]::new()
            }
            $LaneHeroes[$posNum].Add($heroId)
        }
        
        Write-Host "Fetched $($Matches.Count) recent matches from STRATZ"
        foreach ($pos in 1..5) {
            if ($LaneHeroes[$pos]) {
                Write-Host "Position $pos : $($LaneHeroes[$pos].Count) heroes"
            } else {
                Write-Host "Position $pos : 0 heroes"
            }
        }
        
        # Create categories for positions 1-5 (skip empty)
        for ($pos = 1; $pos -le 5; $pos++) {
            $orderedHeroIds = @()
            if ($LaneHeroes[$pos]) {
                # Dedup and sort by Stratz match count for this position (descending)
                $seen = [System.Collections.Generic.HashSet[int]]::new()
                $uniqueIds = @()
                foreach ($id in $LaneHeroes[$pos]) {
                    if ($seen.Add($id)) {
                        $uniqueIds += $id
                    }
                }
                $matchField = "${pos}_match"
                $orderedHeroIds = $uniqueIds | Sort-Object { 
                    $id = $_
                    $h = $Heroes | Where-Object { $_.id -eq $id } | Select-Object -First 1
                    if ($h -and $h.$matchField) { $h.$matchField } else { 0 }
                } -Descending
                
                # Truncate to max_heroes
                if ($orderedHeroIds.Count -gt $RecentMaxHeroes) {
                    $orderedHeroIds = $orderedHeroIds | Select-Object -First $RecentMaxHeroes
                }
            }
            
            if ($orderedHeroIds.Count -gt 0) {
                $RecentPositionCategories += [PSCustomObject]@{
                    category_name = $(if ($pos -eq 1) { $RecentHeroesLabel } else { "" })
                    x_position = $RecentXOffset
                    y_position = $(if ($pos -eq 1) { $InitialY } else { ($pos - 1) * $YOffset })
                    width = $RecentWidth
                    height = $Height
                    hero_ids = $orderedHeroIds
                }
            }
        }
        
        if ($RecentPositionCategories.Count -gt 0) {
            Write-Host "Recent matches: added $($RecentPositionCategories.Count) position categories"
        }
    }
    catch {
        Write-Host "Warning: STRATZ recent matches failed: $($_.Exception.Message)"
    }
}

# Generate grid configs
$TopConfig = New-HeroGridConfig -Heroes $Heroes -PositionFields $PositionFields -MaxHeroes $MaxHeroes -Width $Width -Height $Height -YOffset $YOffset -Y $InitialY -XOffset $XOffset -ConfigPrefix $ConfigPrefix
$RoleCategories = New-DecoratorGrid -YOffset $RoleYOffset -Y $RoleY -Offset 0 -XOffset $RoleXOffset -ConfigPrefix "ROLES" -Heroes $Heroes -PositionFields $PositionFields -RoleNumbers
$WinrateCategories = New-DecoratorGrid -YOffset $WinrateYOffset -Y $WinrateY -Offset 0 -XOffset $WinrateXOffset -ConfigPrefix "WINRATES" -Heroes $Heroes -PositionFields $PositionFields -Count $MaxHeroes -WinrateSeparator $WinrateSeparator

# Append categories to STRATZ config
$TopConfig.configs[0].categories += $RoleCategories.configs[0].categories
$TopConfig.configs[0].categories += $WinrateCategories.configs[0].categories
$TopConfig.configs[0].categories += $RecentPositionCategories

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

    # Backup existing config before overwrite
    if (Test-Path $ConfigPath) {
        Copy-Item $ConfigPath "$ConfigPath.bak" -Force
    }

    # Replace existing generated configs
    $ExistingConfig.configs = @($ExistingConfig.configs | Where-Object { $_.config_name -ne $ConfigPrefix -and $_.config_name -ne "ROLES" -and $_.config_name -ne "WINRATES" })
    $ExistingConfig.configs = @($ExistingConfig.configs) + @($TopConfig.configs)

    $json = $ExistingConfig | ConvertTo-Json -Depth 10 -Compress
    $json = Format-DotaNumbers -Json $json
    $formatted = Format-Json -Json $json
    [System.IO.File]::WriteAllText($ConfigPath, $formatted, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Updated: $ConfigPath"
}

Write-Host "Hero grid generation complete."
