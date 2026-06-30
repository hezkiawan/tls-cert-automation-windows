# Windows TLS Certificate Automation (win-acme)

This repository contains Infrastructure-as-Code (IaC) scripts and reference architectures for automating zero-touch TLS certificate provisioning on Windows Server IIS using the ACME protocol.

The repository is divided into two environments:

- **1-local-simulator** – An educational environment for understanding ACME using a local Pebble CA simulator.
- **2-production-reference** – A production-ready reference implementation for commercial Certificate Authorities such as Sectigo and DigiCert.

---

# 📂 Directory Structure

```text
tls-cert-automation-windows/
├── 1-local-simulator/        # Local Pebble CA testing environment (Archived)
└── 2-production-reference/   # Production automation reference
```

---

# 🧪 1. Local Simulator (Educational Archive)

The **1-local-simulator** directory contains scripts used to experiment with the ACME protocol using **Pebble**, a lightweight local Certificate Authority simulator, together with VirtualBox NAT networking.

> **Status:** Archived (Reference Only)

## Why is it archived?

Although this approach works well in flexible Linux environments (for example Ubuntu with Certbot), Windows Server's native networking and certificate validation stack proved significantly more restrictive during automation testing.

Challenges encountered included:

- **Certificate Revocation Checking (CRL)**  
  Pebble does not provide production-grade Certificate Revocation Lists (CRLs). Windows may reject TLS connections when revocation checking cannot be completed, resulting in errors such as **WinHTTP Error 12175**.

- **Ephemeral Root Certificates**  
  Pebble generates a new root certificate whenever it starts, requiring repeated trust-store updates on Windows.

- **Local Proxy-Based Simulation Limitations**  
  Proxy-based approaches (such as `netsh interface portproxy`) introduced compatibility issues with Windows networking and certificate validation, making the environment unsuitable for reliable automation.

Although not intended for production, this directory remains a useful educational reference for understanding:

- Windows Machine Trust Store management
- Local DNS overrides
- ACME challenge validation
- Manual certificate trust configuration

---

# 🚀 2. Production Reference (For Automated Provisioning)

The **2-production-reference** directory demonstrates how automated TLS provisioning should be implemented in modern cloud environments such as:

- AWS
- Microsoft Azure
- VMware
- Other Windows Server deployments

The implementation uses **win-acme (WACS)** to communicate with a commercial ACME-compatible Certificate Authority (for example, Sectigo or DigiCert) and automatically installs and binds the issued certificate to IIS.

---

## Primary Script

```
userdata-setup.ps1
```

This idempotent PowerShell script is intended to be executed automatically during VM provisioning through:

- Terraform
- AWS EC2 User Data
- Azure Custom Data
- Other Infrastructure-as-Code pipelines

---

## Features

### 🔧 Tooling Bootstrap

Automatically downloads and extracts the latest **win-acme (WACS)** binaries without requiring package managers.

### 🌐 IIS Preparation

Safely checks whether the required HTTP (Port 80) IIS binding exists and creates it if necessary. This binding is required for ACME HTTP-01 domain validation.

### 🔐 External Account Binding (EAB)

Supports commercial Certificate Authorities by supplying:

- EAB Key Identifier
- EAB HMAC Key

These credentials associate certificate requests with the organization's enterprise account.

### 🤖 Zero-Touch Execution

Runs completely unattended using the `--nointeractive` option, making it suitable for automated server provisioning.

### ✅ CI/CD Friendly

Returns appropriate exit codes (`exit 1` on failure) so deployment pipelines can immediately detect provisioning failures.

---

# Production Workflow

The intended deployment flow is:

```text
Provision Windows VM
        │
        ▼
Install IIS
        │
        ▼
Deploy Website Files
        │
        ▼
Create IIS Website
        │
        ▼
Run userdata-setup.ps1
        │
        ▼
Configure HTTP Binding
        │
        ▼
Request Certificate from Sectigo
        │
        ▼
Certificate Installed
        │
        ▼
HTTPS Binding Automatically Configured
```

---

# Using the Production Reference

1. Clone this repository.
2. Integrate `userdata-setup.ps1` into your Infrastructure-as-Code pipeline.
3. Store the following secrets securely using a secret management solution such as:
   - HashiCorp Vault
   - AWS Secrets Manager
   - Azure Key Vault
4. Inject the following values during deployment:
   - `$EabKid`
   - `$EabHmac`
5. Execute the script with **Administrator** (or **SYSTEM**) privileges.

```powershell
.\userdata-setup.ps1
```

---

# Notes

- The **Local Simulator** exists primarily for educational purposes and experimentation with the ACME protocol.
- The **Production Reference** demonstrates the recommended architecture for enterprise Windows environments using commercial ACME-compatible Certificate Authorities.
- Sensitive credentials such as EAB identifiers and HMAC keys should never be hardcoded into source control. Instead, inject them securely during deployment through your organization's secret management platform.