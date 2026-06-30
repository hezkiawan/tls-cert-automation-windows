Write-Host "Fetching Pebble Root CA using native curl.exe..." -ForegroundColor Cyan

# The magic VirtualBox IP that routes to your host machine's port forwards
$PebbleMgmtUrl = "https://10.0.2.2:15000/roots/0"

# Save it directly into your GitHub repository folder!
$CertPath = "C:\tls-cert-automation-windows\1-local-simulator\pebble.minica.crt"

# Use native curl with the -k (--insecure) flag
curl.exe -k $PebbleMgmtUrl -o $CertPath

Write-Host "Injecting Pebble CA into the Windows Local Machine Trust Store..." -ForegroundColor Cyan

# Import the certificate into the Trusted Root Certification Authorities store
Import-Certificate -FilePath $CertPath -CertStoreLocation Cert:\LocalMachine\Root | Out-Null

Write-Host "Trust Bridge Established Successfully!" -ForegroundColor Green