$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$exePath = Join-Path $scriptDir "build\windows\x64\runner\Release\ConvertPrinter.exe"

Write-Host "Adding firewall rules..."

$ruleTCP = Get-NetFirewallRule -DisplayName "LanDropUi TCP" -ErrorAction SilentlyContinue
if (-not $ruleTCP) {
    New-NetFirewallRule -DisplayName "LanDropUi TCP" -Direction Inbound -Protocol TCP -LocalPort 45874 -Action Allow | Out-Null
    Write-Host "  TCP 45874: added"
} else {
    Write-Host "  TCP 45874: exists"
}

$ruleHTTP = Get-NetFirewallRule -DisplayName "HTTP Convert Printers" -ErrorAction SilentlyContinue
if (-not $ruleHTTP) {
    New-NetFirewallRule -DisplayName "HTTP Convert Printers" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow | Out-Null
    Write-Host "  HTTP 8080: added"
} else {
    Write-Host "  HTTP 8080: exists"
}

$ruleApp = Get-NetFirewallRule -DisplayName "Convert Printers" -ErrorAction SilentlyContinue
if (-not $ruleApp) {
    New-NetFirewallRule -DisplayName "Convert Printers" -Direction Inbound -Program $exePath -Action Allow | Out-Null
    Write-Host "  App rule: added"
} else {
    Write-Host "  App rule: exists"
}

Write-Host ""
Write-Host "Starting Convert Printers..."
Start-Process -FilePath $exePath -WorkingDirectory $scriptDir

Start-Sleep -Seconds 2
Write-Host "Done. You can close this window."
