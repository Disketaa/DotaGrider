[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Get-StratzHeroStats {
    [CmdletBinding()]
    param(
        [string]$Token,
        [string]$Bracket = "DIVINE_IMMORTAL",
        [int]$WeeksBack = 4
    )
    
    if (-not $Token) {
        throw "Stratz API token is required. Get one at https://stratz.com/api"
    }
    
    Write-Host "Fetching hero stats from Stratz..."
    
    $bracketList = if ($Bracket -eq "DIVINE_IMMORTAL") { "DIVINE, IMMORTAL" } else { $Bracket }
    
    $allRows = @()
    foreach ($pos in 1..5) {
        $posEnum = "POSITION_$pos"
        
        $queryBody = @{ query = @"
query PositionStats {
  heroStats {
    winWeek(
      take: $WeeksBack,
      bracketIds: [$bracketList],
      positionIds: [$posEnum],
      gameModeIds: [ALL_PICK_RANKED]
    ) {
      heroId
      matchCount
      winCount
    }
  }
}
"@ } | ConvertTo-Json -Compress
        
    $queryPath = Join-Path $env:TEMP "stratz_query_$(New-Guid).json"
    $queryBody | Out-File -FilePath $queryPath -Encoding utf8
        
        try {
            $curlOutput = curl.exe -s -X POST `
                -H "Authorization: Bearer $Token" `
                -H "Content-Type: application/json" `
                -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" `
                -H "Accept: application/json" `
                -H "Accept-Language: en-US,en;q=0.9" `
                --data-binary "@$queryPath" `
                "https://api.stratz.com/graphql" 2>&1
            
            Remove-Item $queryPath -Force -ErrorAction SilentlyContinue
            
            $responseBody = $curlOutput | Out-String
            
            if ($LASTEXITCODE -ne 0 -or $responseBody -like "*Just a moment*" -or $responseBody -like "*cloudflare*") {
                throw "Stratz API blocked (Cloudflare). Debug in GraphiQL: https://api.stratz.com/graphiql"
            }
            
            $response = $responseBody | ConvertFrom-Json
            
            if ($response.errors) {
                $errorMsg = ($response.errors | ForEach-Object { $_.message }) -join "; "
                throw "Stratz GraphQL errors: $errorMsg"
            }
            
            $rows = $response.data.heroStats.winWeek
            if ($rows) {
                foreach ($row in $rows) {
                    $row | Add-Member -NotePropertyName position -NotePropertyValue $posEnum -PassThru -Force
                }
                $allRows += $rows
                Write-Host "Fetched $($rows.Count) rows for position $pos"
            }
        }
        catch {
            if ($_.Exception.Message -like "*Cloudflare*") {
                throw
            }
            throw
        }
    }
    
    if (-not $allRows -or $allRows.Count -eq 0) {
        throw "No hero data returned from Stratz"
    }
    
    Write-Host "Fetched $($allRows.Count) total weekly rows from Stratz"
    
    # Aggregate by heroId + position
    $aggregated = @{}
    foreach ($row in $allRows) {
        $heroId = $row.heroId
        $pos = $row.position
        $posMatch = [regex]::Match($pos, '^POSITION_(\d)$')
        if (-not $posMatch.Success) { continue }
        $posNum = [int]$posMatch.Groups[1].Value
        $key = "$heroId|$posNum"
        
        if (-not $aggregated[$key]) {
            $aggregated[$key] = [ordered]@{
                heroId = $heroId
                position = "POSITION_$posNum"
                matchCount = 0
                winCount = 0
            }
        }
        $aggregated[$key].matchCount += $row.matchCount
        $aggregated[$key].winCount += $row.winCount
    }
    
    $result = $aggregated.Values | ForEach-Object { [PSCustomObject]$_ }
    Write-Host "Aggregated to $($result.Count) position rows"
    return $result
}

function Get-StratzHeroWinrate {
    [CmdletBinding()]
    param(
        [string]$Token,
        [string]$Bracket = "DIVINE_IMMORTAL"
    )
    
    if (-not $Token) {
        throw "Stratz API token is required."
    }
    
    Write-Host "Fetching current hero winrates from Stratz..."
    
    $bracketList = if ($Bracket -eq "DIVINE_IMMORTAL") { "DIVINE, IMMORTAL" } else { $Bracket }
    
    $queryBody = @{ query = @"
query HeroWinrates {
  heroStats {
    winHour(bracketIds: [$bracketList], gameModeIds: [ALL_PICK_RANKED]) {
      heroId
      winCount
      matchCount
    }
  }
}
"@ } | ConvertTo-Json -Compress
    
    $queryPath = Join-Path $env:TEMP "stratz_winrate_query_$(New-Guid).json"
    $queryBody | Out-File -FilePath $queryPath -Encoding utf8
    
    try {
        $curlOutput = curl.exe -s -X POST `
            -H "Authorization: Bearer $Token" `
            -H "Content-Type: application/json" `
            -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" `
            -H "Accept: application/json" `
            -H "Accept-Language: en-US,en;q=0.9" `
            --data-binary "@$queryPath" `
            "https://api.stratz.com/graphql" 2>&1
        
        Remove-Item $queryPath -Force -ErrorAction SilentlyContinue
        
        $responseBody = $curlOutput | Out-String
        
        if ($LASTEXITCODE -ne 0 -or $responseBody -like "*Just a moment*" -or $responseBody -like "*cloudflare*") {
            throw "Stratz API blocked (Cloudflare). Debug in GraphiQL: https://api.stratz.com/graphiql"
        }
        
        $response = $responseBody | ConvertFrom-Json
        
        if ($response.errors) {
            $errorMsg = ($response.errors | ForEach-Object { $_.message }) -join "; "
            throw "Stratz GraphQL errors: $errorMsg"
        }
        
        $rows = $response.data.heroStats.winHour
        if ($rows) {
            Write-Host "Fetched winrate data for $($rows.Count) heroes"
            return $rows
        } else {
            Write-Host "No winrate data returned from Stratz"
            return @()
        }
    }
    catch {
        if ($_.Exception.Message -like "*Cloudflare*") {
            throw
        }
        Write-Host "Warning: Failed to fetch winrate from Stratz: $($_.Exception.Message)"
        return @()
    }
}

function Get-StratzPlayerMatches {
    [CmdletBinding()]
    param(
        [string]$Token,
        [long]$SteamAccountId,
        [int]$Take = 100
    )
    
    if (-not $Token) {
        throw "Stratz API token is required."
    }
    
    Write-Host "Fetching recent matches from Stratz (account: $SteamAccountId)..."
    
    $query = @'
query PlayerMatches($steamAccountId: Long!, $take: Int) {
  player(steamAccountId: $steamAccountId) {
    matches(request: { take: $take }) {
      id
      players {
        steamAccountId
        heroId
        position
      }
    }
  }
}
'@
    
    $queryBody = @{
        query = $query
        variables = @{
            steamAccountId = $SteamAccountId
            take = $Take
        }
    } | ConvertTo-Json -Compress
    
    $queryPath = Join-Path $env:TEMP "stratz_player_matches_$(New-Guid).json"
    $queryBody | Out-File -FilePath $queryPath -Encoding utf8
    
    try {
        $curlOutput = curl.exe -s -X POST `
            -H "Authorization: Bearer $Token" `
            -H "Content-Type: application/json" `
            -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" `
            -H "Accept: application/json" `
            -H "Accept-Language: en-US,en;q=0.9" `
            --data-binary "@$queryPath" `
            "https://api.stratz.com/graphql" 2>&1
        
        Remove-Item $queryPath -Force -ErrorAction SilentlyContinue
        
        $responseBody = $curlOutput | Out-String
        
        if ($LASTEXITCODE -ne 0 -or $responseBody -like "*Just a moment*" -or $responseBody -like "*cloudflare*") {
            throw "Stratz API blocked (Cloudflare). Debug in GraphiQL: https://api.stratz.com/graphiql"
        }
        
        $response = $responseBody | ConvertFrom-Json
        
        if ($response.errors) {
            $errorMsg = ($response.errors | ForEach-Object { $_.message }) -join "; "
            throw "Stratz GraphQL errors: $errorMsg"
        }
        
        $playerMatches = $response.data.player.matches
        if ($playerMatches) {
            Write-Host "Fetched $($playerMatches.Count) matches from Stratz"
            $result = @()
            foreach ($match in $playerMatches) {
                foreach ($player in $match.players) {
                    if ($player.steamAccountId -ne $SteamAccountId) { continue }
                    $result += $player
                }
            }
            return $result
        } else {
            Write-Host "No matches returned from Stratz"
            return @()
        }
    }
    catch {
        if ($_.Exception.Message -like "*Cloudflare*") {
            throw
        }
        Write-Host "Warning: Failed to fetch matches from Stratz: $($_.Exception.Message)"
        return @()
    }
}

Export-ModuleMember -Function Get-StratzHeroStats, Get-StratzHeroWinrate, Get-StratzPlayerMatches
