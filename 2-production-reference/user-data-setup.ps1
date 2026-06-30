<#
==============================================================================
PRODUCTION ACME PROVISIONING SCRIPT (WINDOWS / SECTIGO)

Purpose:
Automates end-to-end TLS certificate provisioning for IIS using the ACME protocol.
Designed to execute unattended during VM provisioning (e.g., Terraform UserData,
Azure Custom Data, EC2 User Data).

High-Level Workflow:
1. Download and install win-acme (WACS).
2. Configure IIS for ACME HTTP-01 validation.
3. Authenticate with the Sectigo ACME endpoint using External Account Binding (EAB).
4. Request a TLS certificate.
5. Automatically install the certificate into the Windows Certificate Store.
6. Automatically bind the certificate to the IIS website.
==============================================================================
#>

#------------------------------------------------------------------------------
# STEP 1 - Download and Prepare win-acme
#
# win-acme (WACS) is the ACME client responsible for:
#   - communicating with the Certificate Authority (Sectigo)
#   - performing ACME challenge validation
#   - requesting certificates
#   - installing certificates into Windows
#   - automatically configuring HTTPS bindings in IIS
#------------------------------------------------------------------------------

Write-Host "📦 Preparing win-acme (WACS) Environment..." -ForegroundColor Cyan

# Installation directory for win-acme
$InstallDir = "C:\win-acme"

# Latest win-acme release
$ExeUrl = "https://github.com/win-acme/win-acme/releases/latest/download/win-acme.v2.2.9.1.x64.zip"

# Create installation directory if it does not already exist.
# This makes the script idempotent and safe to execute multiple times.
if (!(Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
}

# Download win-acme to a temporary location.
$ZipPath = "$env:TEMP\win-acme.zip"
Invoke-WebRequest -Uri $ExeUrl -OutFile $ZipPath

# Extract the binaries.
Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force

# Remove temporary download after extraction.
Remove-Item $ZipPath


<#
==============================================================================
STEP 2 - Configure ACME Endpoint

Commercial Certificate Authorities (such as Sectigo) require
External Account Binding (EAB).

Unlike Let's Encrypt, commercial providers require every ACME client
to authenticate against an existing enterprise account before issuing
certificates.

In production these values should NEVER be hardcoded.
Instead, inject them securely using:
    • HashiCorp Vault
    • Azure Key Vault
    • AWS Secrets Manager
==============================================================================
#>

# Sectigo's ACME API endpoint
$SectigoAcmeUrl = "https://acme.sectigo.com/v2/OV"

# Enterprise account credentials (replace during deployment)
$EabKid  = "<INJECT_SECTIGO_KEY_ID_HERE>"
$EabHmac = "<INJECT_SECTIGO_MAC_KEY_HERE>"

# Domain requiring a TLS certificate
$Domain = "app.helios.com"

# Email used for ACME account registration and expiry notifications
$Email = "admin@helios.com"


#------------------------------------------------------------------------------
# STEP 3 - Prepare IIS for ACME Validation
#
# ACME HTTP-01 validation requires the Certificate Authority to access:
#
# http://app.helios.com/.well-known/acme-challenge/<token>
#
# IIS therefore needs an HTTP binding for the requested hostname.
#
# A binding tells IIS:
#
# "If traffic arrives for app.helios.com on Port 80,
#  route the request to this IIS Site."
#
# The website itself (Default Web Site) is assumed to already exist.
#------------------------------------------------------------------------------

Write-Host "🔧 Configuring IIS default site for $Domain..." -ForegroundColor Yellow

# Load IIS PowerShell cmdlets
Import-Module WebAdministration

# Check whether the required HTTP binding already exists.
# This prevents duplicate bindings if the script executes multiple times.
$existingBinding = Get-WebBinding `
    -Name "Default Web Site" `
    -Port 80 `
    -HostHeader $Domain

# Create the HTTP binding if it is missing.
if (-not $existingBinding) {

    New-WebBinding `
        -Name "Default Web Site" `
        -IPAddress "*" `
        -Port 80 `
        -HostHeader $Domain
}


#------------------------------------------------------------------------------
# STEP 4 - Request and Install TLS Certificate
#
# win-acme performs the following automatically:
#
# 1. Discovers the IIS website.
# 2. Generates a private key.
# 3. Creates a Certificate Signing Request (CSR).
# 4. Authenticates with Sectigo using EAB.
# 5. Completes ACME HTTP-01 validation.
# 6. Downloads the issued certificate.
# 7. Imports it into the Windows Certificate Store.
# 8. Creates an HTTPS (Port 443) IIS binding.
# 9. Associates the certificate with that binding.
#
# No manual IIS certificate installation is required.
#------------------------------------------------------------------------------

Write-Host "🔐 Requesting and Deploying Sectigo SSL Certificate..." -ForegroundColor Cyan

$WacsPath = "$InstallDir\wacs.exe"

# Execute win-acme
#
# --target iis
#       Detect IIS websites automatically.
#
# --siteid 1
#       Target IIS Site ID 1 (Default Web Site).
#
# --host
#       Domain name that will appear on the certificate.
#
# --emailaddress
#       Register ACME account and receive certificate notifications.
#
# --baseuri
#       Commercial Sectigo ACME endpoint.
#
# --eab-key-identifier / --eab-key
#       Enterprise authentication credentials.
#
# --accepttos
#       Automatically accept the CA's Terms of Service.
#
# --nointeractive
#       Execute silently without user prompts (required for automation).

& $WacsPath `
    --target iis `
    --siteid 1 `
    --host $Domain `
    --emailaddress $Email `
    --baseuri $SectigoAcmeUrl `
    --eab-key-identifier $EabKid `
    --eab-key $EabHmac `
    --accepttos `
    --nointeractive


#------------------------------------------------------------------------------
# STEP 5 - Verify Execution Result
#
# win-acme returns an exit code:
#
#   0  = Success
#   >0 = Failure
#
# Returning "exit 1" allows Terraform, CI/CD pipelines,
# or cloud provisioning tools to immediately detect deployment failures.
#------------------------------------------------------------------------------

if ($LASTEXITCODE -ne 0) {

    Write-Host "❌ Provisioning Failed! Check C:\ProgramData\win-acme\logs" -ForegroundColor Red
    exit 1

}
else {

    Write-Host "🎉 Production Deployment Complete! IIS is secured via Sectigo." -ForegroundColor Green

}