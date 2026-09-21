$headers = @{
    "Authorization" = "<SECRET_f934e9d8>"
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    "Accept" = "application/json"
}
$body = '{"query": "query { heroStats { stats(groupByPosition: true) { heroId position matchCount winCount } } }"}'
try {
    $response = Invoke-RestMethod -Uri 'https://api.stratz.com/graphql' -Method Post -ContentType 'application/json' -Body $body -Headers $headers
    $response | ConvertTo-Json -Depth 5 | Select-Object -First 80
} catch {
    Write-Host "Error: $_"
}
