Write-Host "Starting Zero-Touch Certificate Provisioning..." -ForegroundColor Cyan

# Variables
$Domain = "app.windows.local"
$Email = "admin@helios.local"
# Pointing to localhost so the certificate name strictly matches!
$PebbleAcmeUrl = "https://localhost:14444/dir"
$WacsPath = "C:\win-acme\wacs.exe"

# Step 1: Prep the IIS Stage (With Duplicate Protection)
Write-Host "Configuring IIS default site for $Domain..." -ForegroundColor Yellow
Import-Module WebAdministration
$existingBinding = Get-WebBinding -Name "Default Web Site" -Port 80 -HostHeader $Domain
if (-not $existingBinding) {
    New-WebBinding -Name "Default Web Site" -IPAddress "*" -Port 80 -HostHeader $Domain
} else {
    Write-Host "Port 80 binding already exists, skipping creation." -ForegroundColor Gray
}

Write-Host "Executing win-acme in Unattended Mode..." -ForegroundColor Yellow

# Step 2: The Magic Execution
& $WacsPath `
    --target iis `
    --siteid 1 `
    --host $Domain `
    --emailaddress $Email `
    --accepttos `
    --baseuri $PebbleAcmeUrl

if ($LASTEXITCODE -ne 0) {
    Write-Host "win-acme encountered an error!" -ForegroundColor Red
} else {
    Write-Host "Provisioning Complete! Check IIS for the new HTTPS binding." -ForegroundColor Green
}