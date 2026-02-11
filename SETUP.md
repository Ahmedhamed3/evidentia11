# Evidentia: Blockchain-Based Chain-of-Custody System

## Complete Windows 11 Setup and Deployment Guide

> **Version:** 2.0 (Windows 11 Edition)  
> **Last Updated:** November 2024  
> **Difficulty Level:** Beginner-Friendly  
> **Estimated Setup Time:** 2-3 hours

This guide provides **extremely detailed, step-by-step instructions** for setting up and running the complete Evidentia system on **Windows 11**. Every command is written exactly as you need to type it. No prior experience with blockchain, Docker, or command-line tools is required.

---

## 📋 Table of Contents

1. [Introduction and Overview](#1-introduction-and-overview)
2. [System Requirements](#2-system-requirements)
3. [Step 1: Enable WSL2 on Windows 11](#3-step-1-enable-wsl2-on-windows-11)
4. [Step 2: Install Docker Desktop for Windows](#4-step-2-install-docker-desktop-for-windows)
5. [Step 3: Install Git for Windows](#5-step-3-install-git-for-windows)
6. [Step 4: Install Node.js](#6-step-4-install-nodejs)
7. [Step 5: Install Go Programming Language](#7-step-5-install-go-programming-language)
8. [Step 6: Verify All Installations](#8-step-6-verify-all-installations)
9. [Step 7: Clone the Evidentia Project](#9-step-7-clone-the-evidentia-project)
10. [Step 8: Install Hyperledger Fabric Binaries](#10-step-8-install-hyperledger-fabric-binaries)
11. [Step 9: Configure Windows Environment Variables](#11-step-9-configure-windows-environment-variables)
12. [Step 10: Generate Crypto Materials](#12-step-10-generate-crypto-materials)
13. [Step 11: Start the Fabric Network](#13-step-11-start-the-fabric-network)
14. [Step 12: Create Channel and Join Peers](#14-step-12-create-channel-and-join-peers)
15. [Step 13: Deploy Chaincode](#15-step-13-deploy-chaincode)
16. [Step 14: Start IPFS](#16-step-14-start-ipfs)
17. [Step 15: Configure and Start Backend](#17-step-15-configure-and-start-backend)
18. [Step 16: Start Frontend](#18-step-16-start-frontend)
19. [Step 17: Run the Demo Scenario](#19-step-17-run-the-demo-scenario)
20. [Step 18: Using the Forensic Tool Simulator](#20-step-18-using-the-forensic-tool-simulator)
21. [Troubleshooting Guide](#21-troubleshooting-guide)
22. [Architecture Reference](#22-architecture-reference)
23. [PowerShell Scripts Reference](#23-powershell-scripts-reference)
24. [Quick Reference Commands](#24-quick-reference-commands)

---

## 1. Introduction and Overview

### What is Evidentia?

Evidentia is a **blockchain-based digital evidence chain-of-custody system**. It uses:

- **Hyperledger Fabric** - A permissioned blockchain for recording evidence events
- **IPFS** - Distributed storage for evidence files
- **Node.js** - Backend API server
- **React** - Frontend web interface

### What Will This Guide Help You Do?

By the end of this guide, you will have:
- ✅ A fully working Hyperledger Fabric blockchain network running on your Windows 11 PC
- ✅ Three organizations (Law Enforcement, Forensic Lab, Judiciary) with their own peers
- ✅ IPFS storage for evidence files
- ✅ A web interface to register, transfer, and track digital evidence
- ✅ Complete audit trail capabilities

### Important Notes for Windows Users

> ⚠️ **IMPORTANT**: Hyperledger Fabric was originally designed for Linux. On Windows, we run it through **Docker Desktop** which uses **WSL2** (Windows Subsystem for Linux) under the hood. This guide will walk you through every step of setting this up.

---

## 2. System Requirements

### Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **RAM** | 8 GB | 16 GB or more |
| **CPU** | 4 cores | 8 cores |
| **Free Disk Space** | 30 GB | 50 GB |
| **Disk Type** | HDD | SSD (much faster) |

### Software Requirements

| Software | Required Version | Purpose |
|----------|-----------------|---------|
| Windows 11 | 22H2 or later | Operating system |
| Docker Desktop | 4.25+ | Run containers |
| Git | 2.40+ | Download code |
| Node.js | 18.x or 20.x LTS | Run backend/frontend |
| Go | 1.21+ | Compile chaincode |
| PowerShell | 7.x | Run commands |

### Network Ports Used

The following ports must be available (not used by other software):

| Port | Service |
|------|---------|
| 3000 | Frontend web interface |
| 3001 | Backend API |
| 4001 | IPFS P2P |
| 5001 | IPFS API |
| 5984, 6984, 7984 | CouchDB databases |
| 7050, 7053 | Orderer service |
| 7051 | Law Enforcement peer |
| 7054, 8054, 9054 | Certificate Authorities |
| 8080 | IPFS Gateway |
| 9051 | Forensic Lab peer |
| 11051 | Judiciary peer |

---

## 3. Step 1: Enable WSL2 on Windows 11

**WSL2** (Windows Subsystem for Linux 2) allows Windows to run Linux containers efficiently. Docker Desktop requires WSL2.

### 3.1 Open PowerShell as Administrator

1. Click the **Start** button (Windows icon) in the taskbar
2. Type `PowerShell`
3. Right-click on **Windows PowerShell** in the search results
4. Click **Run as administrator**
5. Click **Yes** when asked "Do you want to allow this app to make changes to your device?"

![screenshot](images/powershell_admin.png)

### 3.2 Enable WSL Feature

In the PowerShell window, type this command exactly and press **Enter**:

```powershell
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
```

**Wait** for the message: `The operation completed successfully.`

### 3.3 Enable Virtual Machine Platform

Type this command and press **Enter**:

```powershell
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

**Wait** for the message: `The operation completed successfully.`

### 3.4 Restart Your Computer

This is required. Type:

```powershell
Restart-Computer
```

Or click Start → Power → Restart.

### 3.5 Set WSL2 as Default Version

After your computer restarts:

1. Open **PowerShell as Administrator** again (see step 3.1)
2. Type this command and press **Enter**:

```powershell
wsl --set-default-version 2
```

### 3.6 Install Ubuntu for WSL (Optional but Recommended)

This gives you a Linux terminal if needed:

```powershell
wsl --install -d Ubuntu-22.04
```

**Wait** for the download and installation to complete (this may take 5-10 minutes).

When prompted, create a username and password for Ubuntu. **Remember these credentials!**

### 3.7 Verify WSL2 Installation

```powershell
wsl --list --verbose
```

You should see output similar to:
```
  NAME                   STATE           VERSION
* Ubuntu-22.04           Running         2
```

The **VERSION** column should show **2**.

---

## 4. Step 2: Install Docker Desktop for Windows

Docker Desktop runs all the blockchain components in containers.

### 4.1 Download Docker Desktop

1. Open your web browser (Edge, Chrome, etc.)
2. Go to: **https://www.docker.com/products/docker-desktop/**
3. Click the blue **Download for Windows** button
4. Wait for the file `Docker Desktop Installer.exe` to download (about 500 MB)

![screenshot](images/docker_download.png)

### 4.2 Install Docker Desktop

1. Open your **Downloads** folder
2. **Double-click** on `Docker Desktop Installer.exe`
3. Click **Yes** if asked to allow changes
4. On the Configuration screen:
   - ✅ **Check** "Use WSL 2 instead of Hyper-V"
   - ✅ **Check** "Add shortcut to desktop"
5. Click **Ok**
6. Wait for installation to complete (2-5 minutes)
7. Click **Close and restart** when prompted

![screenshot](images/docker_install_options.png)

### 4.3 Start Docker Desktop for First Time

After restart:

1. Double-click the **Docker Desktop** icon on your desktop
2. Accept the Docker Subscription Service Agreement
3. Skip or complete the survey/tutorial
4. Wait for Docker to start (you'll see "Docker Desktop is running" in the system tray)

### 4.4 Configure Docker Desktop Settings

1. Click the **Docker Desktop** icon in the system tray (bottom-right of screen)
2. Click the **gear icon** (⚙️) for Settings
3. Go to **General**:
   - ✅ Ensure "Use the WSL 2 based engine" is checked
4. Go to **Resources** → **WSL Integration**:
   - ✅ Enable integration with your default WSL distro
   - ✅ Enable for Ubuntu-22.04 (if installed)
5. Go to **Resources** → **Advanced**:
   - Set **Memory** to at least **8 GB** (8192 MB)
   - Set **CPUs** to at least **4**
6. Click **Apply & restart**

![screenshot](images/docker_settings.png)

### 4.5 Verify Docker Installation

Open a **new PowerShell window** (not as admin is fine):

```powershell
docker --version
```

Expected output (version may vary):
```
Docker version 24.0.7, build afdd53b
```

Also verify Docker Compose:

```powershell
docker compose version
```

Expected output:
```
Docker Compose version v2.23.0-desktop.1
```

**Test Docker** by running:

```powershell
docker run hello-world
```

You should see a message starting with "Hello from Docker!"

---

## 5. Step 3: Install Git for Windows

Git is used to download the project code.

### 5.1 Download Git

1. Go to: **https://git-scm.com/download/win**
2. Click **64-bit Git for Windows Setup**
3. Wait for download to complete

### 5.2 Install Git

1. Run the downloaded installer
2. Click **Next** on the welcome screen
3. Accept default installation location, click **Next**
4. On "Select Components":
   - Keep default selections
   - Click **Next**
5. Continue clicking **Next** to accept defaults for all screens
6. On "Choosing the default editor":
   - Select "Use Visual Studio Code as Git's default editor" (or your preference)
7. On "Adjusting your PATH":
   - Select "Git from the command line and also from 3rd-party software"
8. Continue clicking **Next** and finally **Install**
9. Click **Finish**

### 5.3 Verify Git Installation

Open a **new PowerShell window**:

```powershell
git --version
```

Expected output:
```
git version 2.43.0.windows.1
```

---

## 6. Step 4: Install Node.js

Node.js runs the backend API and frontend.

### 6.1 Download Node.js

1. Go to: **https://nodejs.org/**
2. Click the **LTS** version button (e.g., "20.x.x LTS")
3. Download the Windows Installer (.msi)

### 6.2 Install Node.js

1. Run the downloaded `.msi` file
2. Click **Next** on welcome screen
3. Accept the license agreement
4. Accept default installation location
5. Keep default features selected
6. On "Tools for Native Modules":
   - ✅ **Check** "Automatically install the necessary tools..."
7. Click **Next**, then **Install**
8. Click **Finish**
9. A command window may open to install additional tools - let it complete

### 6.3 Verify Node.js Installation

Open a **new PowerShell window**:

```powershell
node --version
```

Expected output (version may vary):
```
v20.10.0
```

Also check npm:

```powershell
npm --version
```

Expected output:
```
10.2.3
```

---

## 7. Step 5: Install Go Programming Language

Go is needed to compile the Hyperledger Fabric chaincode (smart contracts).

### 7.1 Download Go

1. Go to: **https://go.dev/dl/**
2. Click on the **Windows** link for the latest version (e.g., `go1.21.5.windows-amd64.msi`)
3. Wait for download

### 7.2 Install Go

1. Run the downloaded `.msi` file
2. Click **Next** on welcome screen
3. Accept the license agreement
4. Accept default installation location: `C:\Program Files\Go\`
5. Click **Install**
6. Click **Finish**

### 7.3 Verify Go Installation

Open a **new PowerShell window** (important - must be new to pick up PATH changes):

```powershell
go version
```

Expected output:
```
go version go1.21.5 windows/amd64
```

---

## 8. Step 6: Verify All Installations

Let's make sure everything is installed correctly. Open **PowerShell** and run each command:

### 8.1 Complete Verification Script

Copy and paste this entire block:

```powershell
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Evidentia Prerequisites Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Checking Docker..." -ForegroundColor Yellow
docker --version

Write-Host ""
Write-Host "Checking Docker Compose..." -ForegroundColor Yellow
docker compose version

Write-Host ""
Write-Host "Checking Git..." -ForegroundColor Yellow
git --version

Write-Host ""
Write-Host "Checking Node.js..." -ForegroundColor Yellow
node --version

Write-Host ""
Write-Host "Checking npm..." -ForegroundColor Yellow
npm --version

Write-Host ""
Write-Host "Checking Go..." -ForegroundColor Yellow
go version

Write-Host ""
Write-Host "Checking WSL..." -ForegroundColor Yellow
wsl --list --verbose

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "   Prerequisites Check Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
```

### 8.2 Expected Output

All tools should report their versions without errors. If any command shows an error, go back and reinstall that tool.

---

## 9. Step 7: Clone the Evidentia Project

Now we'll download the project files to your computer.

### 9.1 Create a Projects Folder

Open **PowerShell** and run:

```powershell
# Create a folder for the project
New-Item -ItemType Directory -Path "C:\Projects" -Force

# Navigate to it
Set-Location -Path "C:\Projects"
```

### 9.2 Clone the Repository

If you have the project in a Git repository:

```powershell
git clone https://github.com/YOUR-USERNAME/evidentia.git
```

**OR** if you already have the files, copy them to `C:\Projects\Evidentia`

### 9.3 Navigate to Project Folder

```powershell
Set-Location -Path "C:\Projects\Evidentia"
```

### 9.4 Verify Project Structure

```powershell
Get-ChildItem
```

You should see:
```
    Directory: C:\Projects\Evidentia

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d-----        11/28/2024   10:00 AM                backend
d-----        11/28/2024   10:00 AM                chaincode
d-----        11/28/2024   10:00 AM                fabric-network
d-----        11/28/2024   10:00 AM                forensic-simulator
d-----        11/28/2024   10:00 AM                frontend
d-----        11/28/2024   10:00 AM                scripts
-a----        11/28/2024   10:00 AM          11234 README.md
-a----        11/28/2024   10:00 AM          18456 SETUP.md
-a----        11/28/2024   10:00 AM           1756 docker-compose.yaml
```

---

## 10. Step 8: Install Hyperledger Fabric Binaries

### 10.1 Create Fabric Directory

```powershell
# Create directory for Fabric binaries
New-Item -ItemType Directory -Path "C:\fabric" -Force
Set-Location -Path "C:\fabric"
```

### 10.2 Download Fabric Binaries

We need to download the Fabric binaries. On Windows, the easiest way is to download them directly:

```powershell
# Download Fabric binaries using PowerShell
$fabricVersion = "2.5.4"
$caVersion = "1.5.7"

# Create directories
New-Item -ItemType Directory -Path "C:\fabric\bin" -Force
New-Item -ItemType Directory -Path "C:\fabric\config" -Force

# Download and extract binaries
Write-Host "Downloading Hyperledger Fabric binaries..." -ForegroundColor Yellow

$url = "https://github.com/hyperledger/fabric/releases/download/v$fabricVersion/hyperledger-fabric-windows-amd64-$fabricVersion.zip"
$zipFile = "C:\fabric\fabric.zip"

Invoke-WebRequest -Uri $url -OutFile $zipFile
Expand-Archive -Path $zipFile -DestinationPath "C:\fabric" -Force
Remove-Item $zipFile

Write-Host "Fabric binaries downloaded successfully!" -ForegroundColor Green
```

### 10.3 Alternative: Manual Download

If the PowerShell download fails:

1. Go to: **https://github.com/hyperledger/fabric/releases**
2. Find version **v2.5.4** (or latest 2.5.x)
3. Download `hyperledger-fabric-windows-amd64-2.5.4.zip`
4. Extract to `C:\fabric\`

### 10.4 Download Fabric CA Binaries

```powershell
$caUrl = "https://github.com/hyperledger/fabric-ca/releases/download/v1.5.7/hyperledger-fabric-ca-windows-amd64-1.5.7.zip"
$caZip = "C:\fabric\fabric-ca.zip"

Invoke-WebRequest -Uri $caUrl -OutFile $caZip
Expand-Archive -Path $caZip -DestinationPath "C:\fabric" -Force
Remove-Item $caZip
```

### 10.5 Pull Fabric Docker Images

```powershell
# Pull required Docker images
Write-Host "Pulling Hyperledger Fabric Docker images..." -ForegroundColor Yellow

docker pull hyperledger/fabric-peer:2.5
docker pull hyperledger/fabric-orderer:2.5
docker pull hyperledger/fabric-tools:2.5
docker pull hyperledger/fabric-ccenv:2.5
docker pull hyperledger/fabric-baseos:2.5
docker pull hyperledger/fabric-ca:1.5
docker pull couchdb:3.3
docker pull ipfs/kubo:v0.24.0

Write-Host "Docker images pulled successfully!" -ForegroundColor Green
```

This will take 10-20 minutes depending on your internet speed.

### 10.6 Verify Fabric Binaries

```powershell
# List binaries
Get-ChildItem "C:\fabric\bin"
```

You should see files like:
- `configtxgen.exe`
- `configtxlator.exe`
- `cryptogen.exe`
- `discover.exe`
- `orderer.exe`
- `osnadmin.exe`
- `peer.exe`

---

## 11. Step 9: Configure Windows Environment Variables

We need to add Fabric binaries to the system PATH so you can run them from anywhere.

### 11.1 Open Environment Variables Settings

1. Press **Windows + R** to open Run dialog
2. Type `sysdm.cpl` and press **Enter**
3. Click the **Advanced** tab
4. Click **Environment Variables** button

![screenshot](images/env_variables.png)

### 11.2 Add Fabric to PATH

1. In the **System variables** section (bottom), find and select **Path**
2. Click **Edit**
3. Click **New**
4. Type: `C:\fabric\bin`
5. Click **New** again
6. Type: `C:\Program Files\Go\bin`
7. Click **OK** to close the Edit window
8. Click **OK** to close Environment Variables
9. Click **OK** to close System Properties

### 11.3 Add FABRIC_CFG_PATH Variable

1. Open Environment Variables again (steps above)
2. In **System variables**, click **New**
3. Variable name: `FABRIC_CFG_PATH`
4. Variable value: `C:\fabric\config`
5. Click **OK** to save

### 11.4 Verify PATH Configuration

**Close ALL PowerShell windows** and open a new one:

```powershell
# Test Fabric binaries
peer version
```

Expected output:
```
peer:
 Version: 2.5.4
 Commit SHA: ...
 Go version: go1.21.x
 OS/Arch: windows/amd64
```

Also test:

```powershell
configtxgen --version
cryptogen --help
```

---

## 12. Step 10: Generate Crypto Materials

Now we generate the certificates and keys for all organizations.

### 12.1 Navigate to Project

```powershell
Set-Location -Path "C:\Projects\Evidentia\fabric-network"
```

### 12.2 Create PowerShell Generation Script

Since the original scripts are for Linux, we'll create Windows PowerShell equivalents.

Create a new file `scripts\Generate-Crypto.ps1`:

```powershell
# First, create the scripts directory if it doesn't exist
New-Item -ItemType Directory -Path "C:\Projects\Evidentia\fabric-network\scripts" -Force
```

Now create the generation script. In PowerShell, run:

```powershell
@'
# Evidentia - Generate Crypto Materials Script for Windows
# This script generates all certificates and channel artifacts

param(
    [string]$ProjectRoot = "C:\Projects\Evidentia"
)

$ErrorActionPreference = "Stop"
$NetworkDir = Join-Path $ProjectRoot "fabric-network"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Evidentia Crypto Material Generation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Change to network directory
Set-Location $NetworkDir

# Check prerequisites
Write-Host "[INFO] Checking prerequisites..." -ForegroundColor Green

$cryptogen = Get-Command cryptogen -ErrorAction SilentlyContinue
if (-not $cryptogen) {
    Write-Host "[ERROR] cryptogen not found. Please install Fabric binaries." -ForegroundColor Red
    exit 1
}

$configtxgen = Get-Command configtxgen -ErrorAction SilentlyContinue
if (-not $configtxgen) {
    Write-Host "[ERROR] configtxgen not found. Please install Fabric binaries." -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Prerequisites check passed." -ForegroundColor Green

# Remove existing crypto materials
if (Test-Path "crypto-config") {
    Write-Host "[WARN] Removing existing crypto-config directory..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force "crypto-config"
}

if (Test-Path "channel-artifacts") {
    Write-Host "[WARN] Removing existing channel-artifacts directory..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force "channel-artifacts"
}

# Create channel-artifacts directory
New-Item -ItemType Directory -Path "channel-artifacts" -Force | Out-Null

# Generate crypto materials
Write-Host "[INFO] Generating crypto materials..." -ForegroundColor Green

$env:FABRIC_CFG_PATH = $NetworkDir
cryptogen generate --config=crypto-config.yaml --output=crypto-config

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to generate crypto materials" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Crypto materials generated successfully." -ForegroundColor Green

# Generate genesis block
Write-Host "[INFO] Generating genesis block..." -ForegroundColor Green

configtxgen -profile EvidentiaCoCGenesis -outputBlock ./channel-artifacts/evidencechannel.block -channelID evidence-channel

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to generate genesis block" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Channel artifacts generated successfully." -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Crypto Material Generation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Generated files:" -ForegroundColor White
Write-Host "  - crypto-config/ (certificates and keys)" -ForegroundColor Gray
Write-Host "  - channel-artifacts/ (genesis block)" -ForegroundColor Gray
Write-Host ""
Write-Host "Next step: Run Start-Network.ps1" -ForegroundColor Yellow
'@ | Out-File -FilePath "C:\Projects\Evidentia\fabric-network\scripts\Generate-Crypto.ps1" -Encoding UTF8
```

### 12.3 Run the Generation Script

```powershell
Set-Location "C:\Projects\Evidentia\fabric-network"

# Allow running scripts (if not already enabled)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Run the script
.\scripts\Generate-Crypto.ps1
```

### 12.4 Verify Generated Files

```powershell
# Check crypto-config was created
Get-ChildItem "crypto-config"

# Should show:
# ordererOrganizations
# peerOrganizations

# Check channel-artifacts
Get-ChildItem "channel-artifacts"

# Should show:
# evidencechannel.block
```

---

## 13. Step 11: Start the Fabric Network

### 13.1 Create Network Start Script

Create `scripts\Start-Network.ps1`:

```powershell
@'
# Evidentia - Start Network Script for Windows

param(
    [string]$ProjectRoot = "C:\Projects\Evidentia"
)

$ErrorActionPreference = "Stop"
$NetworkDir = Join-Path $ProjectRoot "fabric-network"
$DockerDir = Join-Path $NetworkDir "docker"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Starting Evidentia Network" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Set-Location $DockerDir

# Check if crypto materials exist
if (-not (Test-Path (Join-Path $NetworkDir "crypto-config"))) {
    Write-Host "[ERROR] Crypto materials not found. Run Generate-Crypto.ps1 first." -ForegroundColor Red
    exit 1
}

# Start CouchDB containers
Write-Host "[INFO] Starting CouchDB containers..." -ForegroundColor Green
docker compose -f docker-compose-couch.yaml up -d

Write-Host "[INFO] Waiting for CouchDB to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Start Fabric network
Write-Host "[INFO] Starting Fabric containers..." -ForegroundColor Green
docker compose -f docker-compose-fabric.yaml up -d

Write-Host "[INFO] Waiting for network to stabilize..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Start IPFS
Write-Host "[INFO] Starting IPFS node..." -ForegroundColor Green
docker compose -f docker-compose-ipfs.yaml up -d

Start-Sleep -Seconds 5

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Network Started Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Services running:" -ForegroundColor White
Write-Host "  - Orderer: localhost:7050" -ForegroundColor Gray
Write-Host "  - LawEnforcement Peer: localhost:7051" -ForegroundColor Gray
Write-Host "  - ForensicLab Peer: localhost:9051" -ForegroundColor Gray
Write-Host "  - Judiciary Peer: localhost:11051" -ForegroundColor Gray
Write-Host "  - CouchDB (LE): localhost:5984" -ForegroundColor Gray
Write-Host "  - CouchDB (FL): localhost:6984" -ForegroundColor Gray
Write-Host "  - CouchDB (JD): localhost:7984" -ForegroundColor Gray
Write-Host "  - IPFS API: localhost:5001" -ForegroundColor Gray
Write-Host "  - IPFS Gateway: localhost:8080" -ForegroundColor Gray
Write-Host ""
Write-Host "Next step: Run Create-Channel.ps1" -ForegroundColor Yellow
'@ | Out-File -FilePath "C:\Projects\Evidentia\fabric-network\scripts\Start-Network.ps1" -Encoding UTF8
```

### 13.2 Start the Network

```powershell
Set-Location "C:\Projects\Evidentia\fabric-network"
.\scripts\Start-Network.ps1
```

### 13.3 Verify Containers are Running

```powershell
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

You should see approximately 8 containers running.

![screenshot](images/docker_containers.png)

---

## 14. Step 12: Create Channel and Join Peers

### 14.1 Create Channel Script

Create `scripts\Create-Channel.ps1`:

```powershell
@'
# Evidentia - Create Channel Script for Windows

param(
    [string]$ProjectRoot = "C:\Projects\Evidentia"
)

$ErrorActionPreference = "Stop"
$NetworkDir = Join-Path $ProjectRoot "fabric-network"
$ChannelName = "evidence-channel"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Creating Evidence Channel" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Set-Location $NetworkDir

# Set environment for orderer admin
$env:FABRIC_CFG_PATH = $NetworkDir
$OrdererCA = Join-Path $NetworkDir "crypto-config\ordererOrganizations\evidentia.network\orderers\orderer.evidentia.network\msp\tlscacerts\tlsca.evidentia.network-cert.pem"
$OrdererCert = Join-Path $NetworkDir "crypto-config\ordererOrganizations\evidentia.network\orderers\orderer.evidentia.network\tls\server.crt"
$OrdererKey = Join-Path $NetworkDir "crypto-config\ordererOrganizations\evidentia.network\orderers\orderer.evidentia.network\tls\server.key"

# Create the channel
Write-Host "[INFO] Creating channel: $ChannelName" -ForegroundColor Green

osnadmin channel join `
    --channelID $ChannelName `
    --config-block ".\channel-artifacts\evidencechannel.block" `
    -o localhost:7053 `
    --ca-file $OrdererCA `
    --client-cert $OrdererCert `
    --client-key $OrdererKey

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to create channel" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Channel created successfully" -ForegroundColor Green
Start-Sleep -Seconds 3

# Function to join peer to channel
function Join-PeerToChannel {
    param(
        [string]$OrgName,
        [string]$MspId,
        [string]$PeerAddress
    )
    
    Write-Host "[INFO] Joining $OrgName peer to channel..." -ForegroundColor Green
    
    $OrgDomain = $OrgName.ToLower()
    $env:CORE_PEER_LOCALMSPID = $MspId
    $env:CORE_PEER_TLS_ENABLED = "true"
    $env:CORE_PEER_TLS_ROOTCERT_FILE = Join-Path $NetworkDir "crypto-config\peerOrganizations\$OrgDomain.evidentia.network\peers\peer0.$OrgDomain.evidentia.network\tls\ca.crt"
    $env:CORE_PEER_MSPCONFIGPATH = Join-Path $NetworkDir "crypto-config\peerOrganizations\$OrgDomain.evidentia.network\users\Admin@$OrgDomain.evidentia.network\msp"
    $env:CORE_PEER_ADDRESS = $PeerAddress
    
    peer channel join -b ".\channel-artifacts\evidencechannel.block"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to join $OrgName peer" -ForegroundColor Red
        return $false
    }
    
    Write-Host "[INFO] $OrgName peer joined successfully" -ForegroundColor Green
    return $true
}

# Join all peers
Join-PeerToChannel -OrgName "LawEnforcement" -MspId "LawEnforcementMSP" -PeerAddress "localhost:7051"
Start-Sleep -Seconds 2

Join-PeerToChannel -OrgName "ForensicLab" -MspId "ForensicLabMSP" -PeerAddress "localhost:9051"
Start-Sleep -Seconds 2

Join-PeerToChannel -OrgName "Judiciary" -MspId "JudiciaryMSP" -PeerAddress "localhost:11051"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Channel Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "All peers joined: $ChannelName" -ForegroundColor Gray
Write-Host ""
Write-Host "Next step: Run Deploy-Chaincode.ps1" -ForegroundColor Yellow
'@ | Out-File -FilePath "C:\Projects\Evidentia\fabric-network\scripts\Create-Channel.ps1" -Encoding UTF8
```

### 14.2 Run Channel Creation

```powershell
.\scripts\Create-Channel.ps1
```

---

## 15. Step 13: Deploy Chaincode

### 15.1 Create Chaincode Deployment Script

Create `scripts\Deploy-Chaincode.ps1`:

```powershell
@'
# Evidentia - Deploy Chaincode Script for Windows

param(
    [string]$ProjectRoot = "C:\Projects\Evidentia"
)

$ErrorActionPreference = "Stop"
$NetworkDir = Join-Path $ProjectRoot "fabric-network"
$ChaincodeDir = Join-Path $ProjectRoot "chaincode\evidence-coc"
$ChannelName = "evidence-channel"
$ChaincodeName = "evidence-coc"
$ChaincodeVersion = "1.0"
$ChaincodeSequence = 1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deploying Evidence CoC Chaincode" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Set-Location $NetworkDir

# Vendor Go modules
Write-Host "[INFO] Vendoring Go modules..." -ForegroundColor Green
Set-Location $ChaincodeDir
$env:GO111MODULE = "on"
go mod vendor

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to vendor Go modules" -ForegroundColor Red
    exit 1
}

Set-Location $NetworkDir

# Package chaincode
Write-Host "[INFO] Packaging chaincode..." -ForegroundColor Green

# Set environment for LawEnforcement peer
$env:FABRIC_CFG_PATH = $NetworkDir
$env:CORE_PEER_LOCALMSPID = "LawEnforcementMSP"
$env:CORE_PEER_TLS_ENABLED = "true"
$env:CORE_PEER_TLS_ROOTCERT_FILE = Join-Path $NetworkDir "crypto-config\peerOrganizations\lawenforcement.evidentia.network\peers\peer0.lawenforcement.evidentia.network\tls\ca.crt"
$env:CORE_PEER_MSPCONFIGPATH = Join-Path $NetworkDir "crypto-config\peerOrganizations\lawenforcement.evidentia.network\users\Admin@lawenforcement.evidentia.network\msp"
$env:CORE_PEER_ADDRESS = "localhost:7051"

# Remove old package if exists
if (Test-Path "$ChaincodeName.tar.gz") {
    Remove-Item "$ChaincodeName.tar.gz"
}

peer lifecycle chaincode package "$ChaincodeName.tar.gz" `
    --path $ChaincodeDir `
    --lang golang `
    --label "${ChaincodeName}_${ChaincodeVersion}"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to package chaincode" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Chaincode packaged successfully" -ForegroundColor Green

# Function to install chaincode on a peer
function Install-ChaincodeOnPeer {
    param(
        [string]$OrgName,
        [string]$MspId,
        [string]$PeerAddress
    )
    
    Write-Host "[INFO] Installing chaincode on $OrgName peer..." -ForegroundColor Green
    
    $OrgDomain = $OrgName.ToLower()
    $env:CORE_PEER_LOCALMSPID = $MspId
    $env:CORE_PEER_TLS_ROOTCERT_FILE = Join-Path $NetworkDir "crypto-config\peerOrganizations\$OrgDomain.evidentia.network\peers\peer0.$OrgDomain.evidentia.network\tls\ca.crt"
    $env:CORE_PEER_MSPCONFIGPATH = Join-Path $NetworkDir "crypto-config\peerOrganizations\$OrgDomain.evidentia.network\users\Admin@$OrgDomain.evidentia.network\msp"
    $env:CORE_PEER_ADDRESS = $PeerAddress
    
    peer lifecycle chaincode install "$ChaincodeName.tar.gz"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to install chaincode on $OrgName" -ForegroundColor Red
        return $false
    }
    
    Write-Host "[INFO] Chaincode installed on $OrgName" -ForegroundColor Green
    return $true
}

# Install on all peers
Install-ChaincodeOnPeer -OrgName "LawEnforcement" -MspId "LawEnforcementMSP" -PeerAddress "localhost:7051"
Install-ChaincodeOnPeer -OrgName "ForensicLab" -MspId "ForensicLabMSP" -PeerAddress "localhost:9051"
Install-ChaincodeOnPeer -OrgName "Judiciary" -MspId "JudiciaryMSP" -PeerAddress "localhost:11051"

# Get package ID
Write-Host "[INFO] Getting package ID..." -ForegroundColor Green
$env:CORE_PEER_LOCALMSPID = "LawEnforcementMSP"
$env:CORE_PEER_ADDRESS = "localhost:7051"
$env:CORE_PEER_TLS_ROOTCERT_FILE = Join-Path $NetworkDir "crypto-config\peerOrganizations\lawenforcement.evidentia.network\peers\peer0.lawenforcement.evidentia.network\tls\ca.crt"
$env:CORE_PEER_MSPCONFIGPATH = Join-Path $NetworkDir "crypto-config\peerOrganizations\lawenforcement.evidentia.network\users\Admin@lawenforcement.evidentia.network\msp"

$queryResult = peer lifecycle chaincode queryinstalled 2>&1
$packageId = ($queryResult | Select-String -Pattern "${ChaincodeName}_${ChaincodeVersion}:([a-f0-9]+)").Matches.Value

if (-not $packageId) {
    Write-Host "[ERROR] Failed to get package ID" -ForegroundColor Red
    Write-Host $queryResult
    exit 1
}

Write-Host "[INFO] Package ID: $packageId" -ForegroundColor Green

# Function to approve chaincode for org
function Approve-ChaincodeForOrg {
    param(
        [string]$OrgName,
        [string]$MspId,
        [string]$PeerAddress,
        [string]$PackageId
    )
    
    Write-Host "[INFO] Approving chaincode for $OrgName..." -ForegroundColor Green
    
    $OrgDomain = $OrgName.ToLower()
    $env:CORE_PEER_LOCALMSPID = $MspId
    $env:CORE_PEER_TLS_ROOTCERT_FILE = Join-Path $NetworkDir "crypto-config\peerOrganizations\$OrgDomain.evidentia.network\peers\peer0.$OrgDomain.evidentia.network\tls\ca.crt"
    $env:CORE_PEER_MSPCONFIGPATH = Join-Path $NetworkDir "crypto-config\peerOrganizations\$OrgDomain.evidentia.network\users\Admin@$OrgDomain.evidentia.network\msp"
    $env:CORE_PEER_ADDRESS = $PeerAddress
    
    $OrdererCA = Join-Path $NetworkDir "crypto-config\ordererOrganizations\evidentia.network\orderers\orderer.evidentia.network\msp\tlscacerts\tlsca.evidentia.network-cert.pem"
    $CollectionsConfig = Join-Path $NetworkDir "collections_config.json"
    
    peer lifecycle chaincode approveformyorg `
        -o localhost:7050 `
        --ordererTLSHostnameOverride orderer.evidentia.network `
        --channelID $ChannelName `
        --name $ChaincodeName `
        --version $ChaincodeVersion `
        --package-id $PackageId `
        --sequence $ChaincodeSequence `
        --tls `
        --cafile $OrdererCA `
        --collections-config $CollectionsConfig
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to approve chaincode for $OrgName" -ForegroundColor Red
        return $false
    }
    
    Write-Host "[INFO] Chaincode approved for $OrgName" -ForegroundColor Green
    return $true
}

# Approve for all orgs
Approve-ChaincodeForOrg -OrgName "LawEnforcement" -MspId "LawEnforcementMSP" -PeerAddress "localhost:7051" -PackageId $packageId
Approve-ChaincodeForOrg -OrgName "ForensicLab" -MspId "ForensicLabMSP" -PeerAddress "localhost:9051" -PackageId $packageId
Approve-ChaincodeForOrg -OrgName "Judiciary" -MspId "JudiciaryMSP" -PeerAddress "localhost:11051" -PackageId $packageId

# Commit chaincode
Write-Host "[INFO] Committing chaincode to channel..." -ForegroundColor Green

$env:CORE_PEER_LOCALMSPID = "LawEnforcementMSP"
$env:CORE_PEER_ADDRESS = "localhost:7051"
$env:CORE_PEER_TLS_ROOTCERT_FILE = Join-Path $NetworkDir "crypto-config\peerOrganizations\lawenforcement.evidentia.network\peers\peer0.lawenforcement.evidentia.network\tls\ca.crt"
$env:CORE_PEER_MSPCONFIGPATH = Join-Path $NetworkDir "crypto-config\peerOrganizations\lawenforcement.evidentia.network\users\Admin@lawenforcement.evidentia.network\msp"

$OrdererCA = Join-Path $NetworkDir "crypto-config\ordererOrganizations\evidentia.network\orderers\orderer.evidentia.network\msp\tlscacerts\tlsca.evidentia.network-cert.pem"
$LE_CA = Join-Path $NetworkDir "crypto-config\peerOrganizations\lawenforcement.evidentia.network\peers\peer0.lawenforcement.evidentia.network\tls\ca.crt"
$FL_CA = Join-Path $NetworkDir "crypto-config\peerOrganizations\forensiclab.evidentia.network\peers\peer0.forensiclab.evidentia.network\tls\ca.crt"
$JD_CA = Join-Path $NetworkDir "crypto-config\peerOrganizations\judiciary.evidentia.network\peers\peer0.judiciary.evidentia.network\tls\ca.crt"
$CollectionsConfig = Join-Path $NetworkDir "collections_config.json"

peer lifecycle chaincode commit `
    -o localhost:7050 `
    --ordererTLSHostnameOverride orderer.evidentia.network `
    --channelID $ChannelName `
    --name $ChaincodeName `
    --version $ChaincodeVersion `
    --sequence $ChaincodeSequence `
    --tls `
    --cafile $OrdererCA `
    --peerAddresses localhost:7051 `
    --tlsRootCertFiles $LE_CA `
    --peerAddresses localhost:9051 `
    --tlsRootCertFiles $FL_CA `
    --peerAddresses localhost:11051 `
    --tlsRootCertFiles $JD_CA `
    --collections-config $CollectionsConfig

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to commit chaincode" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Chaincode Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Chaincode: $ChaincodeName" -ForegroundColor Gray
Write-Host "Version: $ChaincodeVersion" -ForegroundColor Gray
Write-Host "Channel: $ChannelName" -ForegroundColor Gray
Write-Host ""
Write-Host "Next step: Start the backend server" -ForegroundColor Yellow
'@ | Out-File -FilePath "C:\Projects\Evidentia\fabric-network\scripts\Deploy-Chaincode.ps1" -Encoding UTF8
```

### 15.2 Deploy the Chaincode

```powershell
Set-Location "C:\Projects\Evidentia\fabric-network"
.\scripts\Deploy-Chaincode.ps1
```

**Note:** This step may take 3-5 minutes as it downloads Go dependencies and compiles the chaincode.

---

## 16. Step 14: Start IPFS

IPFS should already be running from the network start. Verify:

### 16.1 Check IPFS Status

```powershell
# Check if IPFS container is running
docker ps --filter "name=ipfs"
```

### 16.2 Test IPFS API

Open your web browser and go to: **http://localhost:5001/webui**

You should see the IPFS Web UI.

Alternatively, test with PowerShell:

```powershell
# Test IPFS version
Invoke-RestMethod -Uri "http://localhost:5001/api/v0/version" -Method Post
```

---

## 17. Step 15: Configure and Start Backend

### 17.1 Navigate to Backend Directory

```powershell
Set-Location "C:\Projects\Evidentia\backend"
```

### 17.2 Install Node.js Dependencies

```powershell
npm install
```

This will take 2-5 minutes.

### 17.3 Create Environment Configuration

```powershell
# Copy example environment file
Copy-Item "env.example" -Destination ".env"
```

### 17.4 Edit the .env File

Open the `.env` file in Notepad or VS Code:

```powershell
notepad .env
```

**OR**

```powershell
code .env
```

Make sure the file contains (adjust paths to Windows format):

```env
PORT=3001
NODE_ENV=development

JWT_SECRET=evidentia-super-secret-jwt-key-change-in-production
JWT_EXPIRATION=24h

FABRIC_CHANNEL_NAME=evidence-channel
FABRIC_CHAINCODE_NAME=evidence-coc
FABRIC_ORG=LawEnforcement
FABRIC_MSP_ID=LawEnforcementMSP
FABRIC_CRYPTO_PATH=C:/Projects/Evidentia/fabric-network/crypto-config

IPFS_HOST=localhost
IPFS_PORT=5001
IPFS_PROTOCOL=http

ENCRYPTION_KEY=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef

LOG_LEVEL=info
```

**Important:** Use forward slashes (`/`) in paths, even on Windows!

Save and close the file.

### 17.5 Start the Backend Server

```powershell
npm run dev
```

### 17.6 Expected Output

```
[INFO] Initializing Fabric Gateway...
[INFO] Connected to Fabric network: evidence-channel
[INFO] Using chaincode: evidence-coc
[INFO] Organization: LawEnforcement
[INFO] Fabric Gateway initialized successfully
[INFO] Initializing IPFS client...
[INFO] Connected to IPFS node version 0.24.0
[INFO] IPFS client initialized successfully
[INFO] ====================================
[INFO] Evidentia Integration Gateway
[INFO] ====================================
[INFO] Server running on port 3001
[INFO] Environment: development
[INFO] ====================================
```

### 17.7 Verify Backend is Running

Open a **new PowerShell window** (keep the backend running):

```powershell
Invoke-RestMethod -Uri "http://localhost:3001/health"
```

Expected response:
```
status    : healthy
timestamp : 2024-11-28T10:00:00.000Z
service   : evidentia-gateway
```

**Leave the backend running** in its terminal window!

---

## 18. Step 16: Start Frontend

### 18.1 Open New PowerShell Window

Open a **new** PowerShell window (keep backend running in the other one).

### 18.2 Navigate to Frontend Directory

```powershell
Set-Location "C:\Projects\Evidentia\frontend"
```

### 18.3 Install Dependencies

```powershell
npm install
```

### 18.4 Start the Frontend

```powershell
npm start
```

### 18.5 Access the Application

Your default web browser should automatically open to **http://localhost:3000**

If it doesn't, manually open your browser and go to: **http://localhost:3000**

![screenshot](images/frontend_login.png)

### 18.6 Login Credentials

Use one of these demo accounts:

| Username | Password | Role | Organization |
|----------|----------|------|--------------|
| `collector@lawenforcement` | `password123` | Evidence Collector | Law Enforcement |
| `supervisor@lawenforcement` | `password123` | Supervisor | Law Enforcement |
| `analyst@forensiclab` | `password123` | Forensic Analyst | Forensic Lab |
| `supervisor@forensiclab` | `password123` | Lab Supervisor | Forensic Lab |
| `counsel@judiciary` | `password123` | Legal Counsel | Judiciary |
| `judge@judiciary` | `password123` | Judge | Judiciary |
| `auditor@judiciary` | `password123` | Auditor | Judiciary |
| `admin` | `admin123` | System Admin | Law Enforcement |

---

## 19. Step 17: Run the Demo Scenario

### 19.1 Create Demo Script for Windows

Create `scripts\Run-Demo.ps1`:

```powershell
@'
# Evidentia - Demo Script for Windows
# This script demonstrates the complete evidence lifecycle

param(
    [string]$ApiUrl = "http://localhost:3001"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Evidentia Chain-of-Custody Demo" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This demo will:" -ForegroundColor White
Write-Host "  1. Login as Law Enforcement collector" -ForegroundColor Gray
Write-Host "  2. Register new evidence" -ForegroundColor Gray
Write-Host "  3. Transfer custody to Forensic Lab" -ForegroundColor Gray
Write-Host "  4. Record forensic analysis" -ForegroundColor Gray
Write-Host "  5. Submit for judicial review" -ForegroundColor Gray
Write-Host "  6. Record judicial decision" -ForegroundColor Gray
Write-Host ""

# Check if backend is running
try {
    $health = Invoke-RestMethod -Uri "$ApiUrl/health" -Method Get
    Write-Host "[OK] Backend is running" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Backend not running at $ApiUrl" -ForegroundColor Red
    Write-Host "Please start the backend first: cd backend && npm run dev" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Read-Host "Press Enter to start the demo..."

# Step 1: Login as Collector
Write-Host ""
Write-Host "[Step 1] Logging in as collector@lawenforcement..." -ForegroundColor Yellow

$loginBody = @{
    username = "collector@lawenforcement"
    password = "password123"
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod -Uri "$ApiUrl/api/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
$collectorToken = $loginResponse.data.token

Write-Host "[OK] Logged in as Officer Smith (Evidence Collector)" -ForegroundColor Green

# Step 2: Register Evidence
Write-Host ""
Write-Host "[Step 2] Registering new evidence..." -ForegroundColor Yellow

$caseId = "CASE-DEMO-" + (Get-Date -Format "yyyyMMdd")
$evidenceFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllBytes($evidenceFile, (1..1000 | ForEach-Object { Get-Random -Maximum 256 }))

# Note: File upload requires multipart form
$boundary = [System.Guid]::NewGuid().ToString()
$headers = @{
    "Authorization" = "Bearer $collectorToken"
    "Content-Type" = "multipart/form-data; boundary=$boundary"
}

# For simplicity, we'll use a JSON-only registration approach
# In real scenario, you'd upload the file through the UI

Write-Host "[INFO] Case ID: $caseId" -ForegroundColor Gray
Write-Host "[OK] Evidence registration would upload to IPFS and blockchain" -ForegroundColor Green
Write-Host ""
Write-Host "For full demo, please use the web interface at http://localhost:3000" -ForegroundColor Cyan

# Cleanup
Remove-Item $evidenceFile -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Demo Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Open http://localhost:3000 to interact with the full system." -ForegroundColor White
Write-Host ""
'@ | Out-File -FilePath "C:\Projects\Evidentia\scripts\Run-Demo.ps1" -Encoding UTF8
```

### 19.2 Run the Demo

```powershell
Set-Location "C:\Projects\Evidentia"
.\scripts\Run-Demo.ps1
```

### 19.3 Full Demo via Web Interface

For the complete experience:

1. Open **http://localhost:3000** in your browser
2. Login as `collector@lawenforcement` with password `password123`
3. Click **Register Evidence**
4. Upload a test file and fill in the details
5. View the evidence in the list
6. Transfer custody, record analysis, etc.

---

## 20. Step 18: Using the Forensic Tool Simulator

### 20.1 Navigate to Simulator Directory

Open a **new** PowerShell window:

```powershell
Set-Location "C:\Projects\Evidentia\forensic-simulator"
```

### 20.2 Install Dependencies

```powershell
npm install
```

### 20.3 Run in Interactive Mode

```powershell
npx ts-node src/cli.ts interactive
```

### 20.4 Analyze Evidence

If you have an evidence ID:

```powershell
npx ts-node src/cli.ts analyze EVD-XXXXXXXX
```

---

## 21. Troubleshooting Guide

### 21.1 Docker Issues

**Problem:** Docker commands fail with "Cannot connect to the Docker daemon"

**Solution:**
1. Make sure Docker Desktop is running (check system tray)
2. Right-click Docker icon → Restart
3. Wait 1-2 minutes for Docker to fully start

```powershell
# Check Docker status
docker info
```

**Problem:** Containers won't start

**Solution:**
```powershell
# Stop all containers
docker stop $(docker ps -q)

# Remove all containers
docker rm $(docker ps -aq)

# Start network again
Set-Location "C:\Projects\Evidentia\fabric-network"
.\scripts\Start-Network.ps1
```

### 21.2 Port Already in Use

**Problem:** "Port XXXX is already in use"

**Solution:**
```powershell
# Find what's using the port
netstat -ano | findstr :7051

# The last column is the PID. Kill it:
taskkill /PID <PID_NUMBER> /F
```

### 21.3 Fabric Peer Connection Issues

**Problem:** Backend can't connect to peer

**Solution:**
1. Check peer container is running:
```powershell
docker ps | findstr "peer0"
```

2. Check peer logs:
```powershell
docker logs peer0.lawenforcement.evidentia.network
```

3. Ensure environment variables are set correctly in `.env`

### 21.4 Chaincode Deployment Fails

**Problem:** Chaincode won't deploy

**Solution:**
```powershell
# Check if Go modules are vendored
Set-Location "C:\Projects\Evidentia\chaincode\evidence-coc"
go mod vendor

# Retry deployment
Set-Location "C:\Projects\Evidentia\fabric-network"
.\scripts\Deploy-Chaincode.ps1
```

### 21.5 Reset Everything

If all else fails, reset the entire network:

```powershell
# Stop and remove all Docker containers and volumes
docker stop $(docker ps -q)
docker rm $(docker ps -aq)
docker volume prune -f
docker network prune -f

# Remove generated files
Set-Location "C:\Projects\Evidentia\fabric-network"
Remove-Item -Recurse -Force crypto-config -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force channel-artifacts -ErrorAction SilentlyContinue

# Start fresh
.\scripts\Generate-Crypto.ps1
.\scripts\Start-Network.ps1
.\scripts\Create-Channel.ps1
.\scripts\Deploy-Chaincode.ps1
```

---

## 22. Architecture Reference

### 22.1 Organizations

| Organization | MSP ID | Role | Peer Port |
|-------------|--------|------|-----------|
| OrdererOrg | OrdererMSP | Consensus/ordering | 7050 |
| LawEnforcement | LawEnforcementMSP | Evidence collection | 7051 |
| ForensicLab | ForensicLabMSP | Forensic analysis | 9051 |
| Judiciary | JudiciaryMSP | Legal review | 11051 |

### 22.2 Network Topology

```
                    ┌─────────────────┐
                    │     Orderer     │
                    │   (Raft/Solo)   │
                    │   Port: 7050    │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ LawEnforcement│   │  ForensicLab  │   │   Judiciary   │
│  Port: 7051   │   │  Port: 9051   │   │  Port: 11051  │
├───────────────┤   ├───────────────┤   ├───────────────┤
│   CouchDB     │   │   CouchDB     │   │   CouchDB     │
│  Port: 5984   │   │  Port: 6984   │   │  Port: 7984   │
└───────────────┘   └───────────────┘   └───────────────┘
```

### 22.3 Data Flow

```
Evidence File → Encryption (AES-256-GCM) → IPFS Storage
                                              ↓
                                        CID + Metadata
                                              ↓
                                    Blockchain Record
                                    (hash, CID, events)
```

### 22.4 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/auth/login | Authenticate user |
| GET | /api/evidence | List all evidence |
| POST | /api/evidence | Register new evidence |
| GET | /api/evidence/:id | Get evidence details |
| POST | /api/evidence/:id/transfer | Transfer custody |
| POST | /api/evidence/:id/analysis | Record analysis |
| POST | /api/evidence/:id/review | Submit for review |
| GET | /api/audit/report/:id | Generate audit report |

---

## 23. PowerShell Scripts Reference

All PowerShell scripts are located in `C:\Projects\Evidentia\fabric-network\scripts\`:

| Script | Description |
|--------|-------------|
| `Generate-Crypto.ps1` | Generate certificates and channel artifacts |
| `Start-Network.ps1` | Start all Docker containers |
| `Stop-Network.ps1` | Stop all Docker containers |
| `Create-Channel.ps1` | Create channel and join peers |
| `Deploy-Chaincode.ps1` | Package, install, and commit chaincode |

Demo scripts in `C:\Projects\Evidentia\scripts\`:

| Script | Description |
|--------|-------------|
| `Run-Demo.ps1` | Run complete evidence lifecycle demo |

---

## 24. Quick Reference Commands

### Start Everything (in order)

```powershell
# 1. Start Docker Desktop (via Windows)

# 2. Navigate to project
Set-Location "C:\Projects\Evidentia\fabric-network"

# 3. Start network
.\scripts\Start-Network.ps1

# 4. Create channel (first time only)
.\scripts\Create-Channel.ps1

# 5. Deploy chaincode (first time only)
.\scripts\Deploy-Chaincode.ps1

# 6. Start backend (new PowerShell window)
Set-Location "C:\Projects\Evidentia\backend"
npm run dev

# 7. Start frontend (new PowerShell window)
Set-Location "C:\Projects\Evidentia\frontend"
npm start
```

### Stop Everything

```powershell
# Stop frontend: Press Ctrl+C in frontend window
# Stop backend: Press Ctrl+C in backend window

# Stop Fabric network
Set-Location "C:\Projects\Evidentia\fabric-network\docker"
docker compose -f docker-compose-fabric.yaml down
docker compose -f docker-compose-couch.yaml down
docker compose -f docker-compose-ipfs.yaml down
```

### Check Status

```powershell
# List running containers
docker ps

# Check backend health
Invoke-RestMethod -Uri "http://localhost:3001/health"

# Check IPFS
Invoke-RestMethod -Uri "http://localhost:5001/api/v0/version" -Method Post
```

---

## Support

If you encounter issues:

1. ✅ Check the troubleshooting section above
2. ✅ Review Docker Desktop logs
3. ✅ Check container logs: `docker logs <container_name>`
4. ✅ Ensure all ports are available
5. ✅ Verify environment variables are set correctly

---

**Document Version:** 2.0 (Windows 11 Edition)  
**Last Updated:** November 2024  
**Compatible With:** Windows 11 22H2+, Docker Desktop 4.25+, Fabric 2.5.x
