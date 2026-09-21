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
    
    $headers = @{
        "Authorization" = "Bearer $Token"
        "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        "Accept" = "application/json"
    }
    
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
        if ($pos -notmatch 'POSITION_(\d)') { continue }
        $posNum = [int]$matches[1]
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

Export-ModuleMember -Function Get-StratzHeroStats
