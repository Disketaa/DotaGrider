[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Read-Settings {
    [CmdletBinding()]
    param(
        [string]$Path = "Content\Settings.toml"
    )
    
    if (-not (Test-Path $Path)) {
        throw "Settings file not found: $Path"
    }
    
    $settings = @{}
    $currentSection = $null
    
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        
        if ($line -match '^\[(.+)\]$') {
            $currentSection = $matches[1]
            $settings[$currentSection] = @{}
        }
        elseif ($line -match '^([^=]+)\s*=\s*"(.+)"$') {
            $key = $matches[1].Trim()
            $value = $matches[2]
            if ($currentSection) {
                $settings[$currentSection][$key] = $value
            }
        }
        elseif ($line -match '^([^=]+)\s*=\s*(\d+)$') {
            $key = $matches[1].Trim()
            $value = [int]$matches[2]
            if ($currentSection) {
                $settings[$currentSection][$key] = $value
            }
        }
    }
    
    return $settings
}

Export-ModuleMember -Function Read-Settings
