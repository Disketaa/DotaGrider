[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Get-StratzHeroStats {
    [CmdletBinding()]
    param(
        [string]$Token
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
    
    $queryBody = @{ query = @"
query PositionStats {
  heroStats {
    stats(groupByPosition: true) {
      heroId
      position
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
        
        $rows = $response.data.heroStats.stats
        if (-not $rows -or $rows.Count -eq 0) {
            throw "No hero data returned from Stratz"
        }
        
        Write-Host "Fetched $($rows.Count) position rows from Stratz"
        return $rows
    }
    catch {
        if ($_.Exception.Message -like "*Cloudflare*") {
            throw
        }
        throw
    }
}

Export-ModuleMember -Function Get-StratzHeroStats
