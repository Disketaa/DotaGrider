@echo off
cd /d "%~dp0"
setlocal enabledelayedexpansion

if not exist "Settings.toml" (
    echo === First Run Setup ===
    echo Settings.toml not found. Creating with defaults.
    set /p token="Enter your Stratz API token (get one at https://stratz.com/api): "
    if "!token!"=="" (
        echo Token is required. Exiting.
        pause
        exit /b 1
    )
    set /p account_id="Enter your OpenDota account ID (32-bit, find it at https://www.opendota.com/players/YOUR_STEAM_ID): "
    powershell -ExecutionPolicy Bypass -NoProfile -File "Modules\SetupSettings.ps1" -Token "!token!" -AccountId "!account_id!"
    echo Settings.toml created.
)

powershell -ExecutionPolicy Bypass -NoProfile -File "GenerateHeroGrid.ps1"
%*