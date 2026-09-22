param(
    [string]$Token,
    [string]$AccountId
)

$lines = @(
    '# DotaGrider Settings',
    'language = "Russian"',
    '',
    '[api]',
    'provider = "stratz"',
    "stratz_token = `"$Token`"",
    'stratz_bracket = "DIVINE"',
    'stratz_weeks_back = 1',
    '',
    '[stratz_grid]',
    'config_prefix = "STRATZ"',
    'y = 0',
    'x_offset = 20',
    'y_offset = 110',
    'width = 750',
    'height = 100',
    'max_heroes = 10',
    '',
    '[opendota]',
    "account_id = `"$AccountId`"",
    'match_limit = 500',
    '',
    '[recent_grid]',
    'x_offset = 720',
    'width = 750',
    'max_heroes = 6',
    '',
    '[role_grid]',
    'y = 62',
    'x_offset = 0',
    'y_offset = 110',
    '',
    '[winrate_grid]',
    'separator = "    "',
    'y = 115',
    'x_offset = 34',
    'y_offset = 110',
    '',
    '[steam]',
    'steam_path = "C:\\Program Files (x86)\\Steam"'
)

$settingsPath = Join-Path $PSScriptRoot "..\Settings.toml"
[System.IO.File]::WriteAllLines($settingsPath, $lines, [System.Text.UTF8Encoding]::new($false))
Write-Host "Settings.toml created."
