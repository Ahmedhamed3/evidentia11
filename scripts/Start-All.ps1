# Evidentia - Start All Services Script for Windows
# This script starts the complete Evidentia system

param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [switch]$SkipNetwork,
    [switch]$BackendOnly,
    [switch]$FrontendOnly
)

$ErrorActionPreference = "Stop"

# If ProjectRoot is not set correctly, try to find it
if (-not (Test-Path (Join-Path $ProjectRoot "fabric-network"))) {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Evidentia - Start All Services" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check Docker is running
if (-not $SkipNetwork) {
    Write-Host "[INFO] Checking Docker..." -ForegroundColor Green
    $dockerCheck = $false
    try {
        # Try a simple docker command - suppress all output and check exit code
        docker ps --format "{{.Names}}" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $dockerCheck = $true
        }
    } catch {
        $dockerCheck = $false
    }
    
    if (-not $dockerCheck) {
        Write-Host "[ERROR] Docker Desktop is not running!" -ForegroundColor Red
        Write-Host "Please start Docker Desktop first." -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "[OK] Docker is running" -ForegroundColor Green
}

# Check if network is already running
$networkRunning = docker ps --filter "name=orderer.evidentia" --format "{{.Names}}" 2>$null

if (-not $SkipNetwork) {
    if ($networkRunning) {
        Write-Host "[OK] Fabric network already running" -ForegroundColor Green
    } else {
        Write-Host "[INFO] Starting Fabric network..." -ForegroundColor Yellow
        
        # Check if crypto materials exist
        if (-not (Test-Path (Join-Path $ProjectRoot "fabric-network\crypto-config"))) {
            Write-Host "[WARN] Crypto materials not found. Generating..." -ForegroundColor Yellow
            & (Join-Path $ProjectRoot "fabric-network\scripts\Generate-Crypto.ps1")
        }
        
        # Start network
        & (Join-Path $ProjectRoot "fabric-network\scripts\Start-Network.ps1")
        
        # Check if channel exists
        # If not, create it (first time only)
        Write-Host "[INFO] Note: If this is the first run, you may need to run:" -ForegroundColor Yellow
        Write-Host "  .\fabric-network\scripts\Create-Channel.ps1" -ForegroundColor Gray
        Write-Host "  .\fabric-network\scripts\Deploy-Chaincode.ps1" -ForegroundColor Gray
    }
}

Write-Host ""

if (-not $FrontendOnly) {
    # Start Backend
    Write-Host "[INFO] Starting Backend service..." -ForegroundColor Yellow
    
    $backendDir = Join-Path $ProjectRoot "backend"
    
    # Check if node_modules exists
    if (-not (Test-Path (Join-Path $backendDir "node_modules"))) {
        Write-Host "[INFO] Installing backend dependencies..." -ForegroundColor Gray
        Set-Location $backendDir
        npm install
    }
    
    # Check if .env exists
    if (-not (Test-Path (Join-Path $backendDir ".env"))) {
        Write-Host "[INFO] Creating .env from env.example..." -ForegroundColor Gray
        Copy-Item (Join-Path $backendDir "env.example") -Destination (Join-Path $backendDir ".env")
    }
    
    # Start backend in new window
    Write-Host "[INFO] Opening new PowerShell window for backend..." -ForegroundColor Gray
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$backendDir'; npm run dev"
    
    Write-Host "[OK] Backend starting at http://localhost:3001" -ForegroundColor Green
}

if (-not $BackendOnly) {
    # Wait for backend to be ready
    Write-Host "[INFO] Waiting for backend to be ready..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    
    # Start Frontend
    Write-Host "[INFO] Starting Frontend service..." -ForegroundColor Yellow
    
    $frontendDir = Join-Path $ProjectRoot "frontend"
    
    # Check if node_modules exists
    if (-not (Test-Path (Join-Path $frontendDir "node_modules"))) {
        Write-Host "[INFO] Installing frontend dependencies..." -ForegroundColor Gray
        Set-Location $frontendDir
        npm install
    }
    
    # Start frontend in new window
    Write-Host "[INFO] Opening new PowerShell window for frontend..." -ForegroundColor Gray
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$frontendDir'; npm start"
    
    Write-Host "[OK] Frontend starting at http://localhost:3000" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  All Services Starting!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Services:" -ForegroundColor White
Write-Host "  - Fabric Network: Running in Docker" -ForegroundColor Gray
Write-Host "  - Backend API: http://localhost:3001" -ForegroundColor Gray
Write-Host "  - Frontend UI: http://localhost:3000" -ForegroundColor Gray
Write-Host ""
Write-Host "Two new PowerShell windows should have opened." -ForegroundColor Yellow
Write-Host "Wait a few seconds for services to fully start." -ForegroundColor Yellow
Write-Host ""
Write-Host "Default login: admin / admin123" -ForegroundColor Cyan
Write-Host ""

