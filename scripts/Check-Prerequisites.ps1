# Evidentia - Prerequisites Check Script for Windows
# This script checks that all required software is installed

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Evidentia Prerequisites Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$allPassed = $true

# Helper function
function Test-Prerequisite {
    param(
        [string]$Name,
        [string]$Command,
        [string]$MinVersion,
        [string]$InstallUrl
    )
    
    Write-Host "Checking $Name..." -ForegroundColor Yellow
    
    try {
        $output = & cmd /c "$Command 2>&1"
        $version = [regex]::Match($output, '\d+\.\d+(\.\d+)?').Value
        
        if ($version) {
            Write-Host "  [OK] $Name version: $version" -ForegroundColor Green
            return $true
        } else {
            throw "Could not determine version"
        }
    } catch {
        Write-Host "  [ERROR] $Name not found or not working" -ForegroundColor Red
        Write-Host "  Install from: $InstallUrl" -ForegroundColor Gray
        return $false
    }
}

Write-Host "1. Windows Version" -ForegroundColor Cyan
Write-Host "   " -NoNewline
$winVer = [System.Environment]::OSVersion.Version
$winBuild = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion
Write-Host "[OK] Windows $winBuild (Build $($winVer.Build))" -ForegroundColor Green

Write-Host ""
Write-Host "2. WSL2" -ForegroundColor Cyan
try {
    $wslOutput = wsl --list --verbose 2>&1
    if ($wslOutput -match "VERSION.*2" -or $wslOutput -match "2$") {
        Write-Host "   [OK] WSL2 is available" -ForegroundColor Green
    } else {
        Write-Host "   [WARN] WSL2 may not be configured. Run: wsl --set-default-version 2" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   [ERROR] WSL not installed. See SETUP.md for instructions." -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""
Write-Host "3. Docker Desktop" -ForegroundColor Cyan
$dockerOk = Test-Prerequisite -Name "Docker" `
    -Command "docker --version" `
    -MinVersion "24.0" `
    -InstallUrl "https://www.docker.com/products/docker-desktop/"

if (-not $dockerOk) { $allPassed = $false }

# Check Docker is running
try {
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   [OK] Docker daemon is running" -ForegroundColor Green
    } else {
        Write-Host "   [WARN] Docker installed but not running. Start Docker Desktop." -ForegroundColor Yellow
    }
} catch {
    Write-Host "   [WARN] Could not connect to Docker daemon" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "4. Docker Compose" -ForegroundColor Cyan
$composeOk = Test-Prerequisite -Name "Docker Compose" `
    -Command "docker compose version" `
    -MinVersion "2.0" `
    -InstallUrl "Included with Docker Desktop"

if (-not $composeOk) { $allPassed = $false }

Write-Host ""
Write-Host "5. Git" -ForegroundColor Cyan
$gitOk = Test-Prerequisite -Name "Git" `
    -Command "git --version" `
    -MinVersion "2.40" `
    -InstallUrl "https://git-scm.com/download/win"

if (-not $gitOk) { $allPassed = $false }

Write-Host ""
Write-Host "6. Node.js" -ForegroundColor Cyan
$nodeOk = Test-Prerequisite -Name "Node.js" `
    -Command "node --version" `
    -MinVersion "18.0" `
    -InstallUrl "https://nodejs.org/"

if (-not $nodeOk) { $allPassed = $false }

Write-Host ""
Write-Host "7. npm" -ForegroundColor Cyan
$npmOk = Test-Prerequisite -Name "npm" `
    -Command "npm --version" `
    -MinVersion "9.0" `
    -InstallUrl "Included with Node.js"

if (-not $npmOk) { $allPassed = $false }

Write-Host ""
Write-Host "8. Go" -ForegroundColor Cyan
$goOk = Test-Prerequisite -Name "Go" `
    -Command "go version" `
    -MinVersion "1.21" `
    -InstallUrl "https://go.dev/dl/"

if (-not $goOk) { $allPassed = $false }

Write-Host ""
Write-Host "9. Hyperledger Fabric Binaries" -ForegroundColor Cyan

$fabricBins = @("peer", "configtxgen", "cryptogen", "osnadmin")
$fabricOk = $true

foreach ($bin in $fabricBins) {
    $cmd = Get-Command $bin -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Host "   [OK] $bin found at: $($cmd.Source)" -ForegroundColor Green
    } else {
        Write-Host "   [ERROR] $bin not found in PATH" -ForegroundColor Red
        $fabricOk = $false
    }
}

if (-not $fabricOk) {
    Write-Host "   " -ForegroundColor Gray
    Write-Host "   Download Fabric binaries from:" -ForegroundColor Yellow
    Write-Host "   https://github.com/hyperledger/fabric/releases" -ForegroundColor Gray
    Write-Host "   Extract to C:\fabric\bin and add to PATH" -ForegroundColor Gray
    $allPassed = $false
}

Write-Host ""
Write-Host "10. Environment Variables" -ForegroundColor Cyan

$fabricCfgPath = $env:FABRIC_CFG_PATH
if ($fabricCfgPath) {
    Write-Host "   [OK] FABRIC_CFG_PATH = $fabricCfgPath" -ForegroundColor Green
} else {
    Write-Host "   [WARN] FABRIC_CFG_PATH not set (will use defaults)" -ForegroundColor Yellow
}

$goPath = $env:GOPATH
if ($goPath) {
    Write-Host "   [OK] GOPATH = $goPath" -ForegroundColor Green
} else {
    Write-Host "   [INFO] GOPATH not set (using default)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

if ($allPassed) {
    Write-Host "  All Prerequisites Satisfied!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "You're ready to set up Evidentia!" -ForegroundColor White
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. .\fabric-network\scripts\Generate-Crypto.ps1" -ForegroundColor Gray
    Write-Host "  2. .\fabric-network\scripts\Start-Network.ps1" -ForegroundColor Gray
    Write-Host "  3. .\fabric-network\scripts\Create-Channel.ps1" -ForegroundColor Gray
    Write-Host "  4. .\fabric-network\scripts\Deploy-Chaincode.ps1" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "  Some Prerequisites Missing" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Please install the missing software before continuing." -ForegroundColor Yellow
    Write-Host "See SETUP.md for detailed installation instructions." -ForegroundColor Gray
    Write-Host ""
    exit 1
}

