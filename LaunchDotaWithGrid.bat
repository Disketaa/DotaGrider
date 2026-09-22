@echo off
cd /d "%~dp0"

if not exist "Settings.toml" (
    echo ERROR: Settings.toml not found.
    echo Create Settings.toml with grid and language settings.
    pause
    exit /b 1
)

if not exist "Token.toml" (
    echo ERROR: Token.toml not found.
    echo Create Token.toml with stratz_token and stratz_account_id under [api].
    pause
    exit /b 1
)

powershell -ExecutionPolicy Bypass -NoProfile -File "GenerateHeroGrid.ps1"
if errorlevel 1 (
    echo ERROR: Hero grid generation failed. Check messages above.
    pause
    exit /b 1
)

%*