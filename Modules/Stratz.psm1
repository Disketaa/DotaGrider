[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Get-StratzHeroStats {
    [CmdletBinding()]
    param(
        [string]$Token,
        [string]$GraphqlUrl = "https://api.stratz.com/graphql"
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
    
    $query = @{
        query = @"
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
"@
    } | ConvertTo-Json -Compress
    
    try {
        $response = Invoke-RestMethod -Uri $GraphqlUrl -Method Post -ContentType 'application/json' -Body $query -Headers $headers
        
        if ($response.errors) {
            $errorMsg = $response.errors | ForEach-Object { $_.message } | Join-String -Separator "; "
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
        if ($_.Exception.Response.StatusCode -eq 403 -or $_.Exception.Message -like "*Just a moment*") {
            throw "Stratz API blocked (Cloudflare). Debug in GraphiQL: https://api.stratz.com/graphiql"
        }
        throw
    }
}

Export-ModuleMember -Function Get-StratzHeroStats
