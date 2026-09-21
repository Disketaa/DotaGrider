# Dota 2 Hero Grid Generator

Automatically generates and updates Dota 2 hero grids based on OpenDota stats on game launch.

## Setup

1. Set Dota 2 launch options to:
   ```
   cmd /c start "" "C:\Projects\DotaGrider\LaunchDotaWithGrid.bat" %command%
   ```

2. That's it. The grid will be generated/updated each time Dota 2 launches.

## How It Works

- `launch_dota_with_grid.bat` runs `Generate-HeroGrid.ps1` before launching Dota 2
- The PowerShell script fetches latest hero stats from OpenDota API
- Generates hero grid configs for each role (Carry, Mid, Offlane, Support, Hard Support)
- **Merges with existing hero grids** - does not overwrite user-created configs
- Works for all Steam users on the PC (universal)

## Generated Grids

- Top Carry Heroes (top 15 by pick rate)
- All Carry Heroes
- Top Mid Heroes (top 15 by pick rate)
- All Mid Heroes
- Top Offlane Heroes (top 15 by pick rate)
- All Offlane Heroes
- Top Support Heroes (top 15 by pick rate)
- All Support Heroes
- Top Hard Support Heroes (top 15 by pick rate)
- All Hard Support Heroes

## Files

- `LaunchDotaWithGrid.bat` - Steam launch option wrapper
- `GenerateHeroGrid.ps1` - Main script that fetches stats and updates config

## Requirements

- Windows with Steam installed
- PowerShell 5.1+
- Internet connection (to fetch hero stats from OpenDota)
