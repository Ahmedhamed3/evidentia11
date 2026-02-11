# Evidentia - Start Network Script for Windows
# This script starts all Docker containers for the Fabric network

param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
)

$ErrorActionPreference = "Stop"

# If ProjectRoot is not set correctly, try to find it
if (-not (Test-Path (Join-Path $ProjectRoot "fabric-network"))) {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

$NetworkDir = Join-Path $ProjectRoot "fabric-network"
$DockerDir = Join-Path $NetworkDir "docker"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Starting Evidentia Network" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check Docker is running
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
    Write-Host "[ERROR] Docker is not running!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please start Docker Desktop:" -ForegroundColor Yellow
    Write-Host "  1. Click the Docker Desktop icon in your system tray" -ForegroundColor Gray
    Write-Host "  2. Or search for 'Docker Desktop' in the Start menu" -ForegroundColor Gray
    Write-Host "  3. Wait for Docker to fully start (whale icon stops animating)" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host "[OK] Docker is running" -ForegroundColor Green

Set-Location $DockerDir

# Check if crypto materials exist
if (-not (Test-Path (Join-Path $NetworkDir "crypto-config"))) {
    Write-Host "[ERROR] Crypto materials not found." -ForegroundColor Red
    Write-Host ""
    Write-Host "Please run Generate-Crypto.ps1 first:" -ForegroundColor Yellow
    Write-Host "  .\scripts\Generate-Crypto.ps1" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host "[OK] Crypto materials found" -ForegroundColor Green
Write-Host ""

# Create Docker network if not exists
Write-Host "[INFO] Creating Docker network..." -ForegroundColor Green
$networkExists = docker network ls --filter "name=evidentia_network" --format "{{.Name}}" 2>$null
if (-not $networkExists) {
    docker network create evidentia_network
    Write-Host "[OK] Docker network 'evidentia_network' created" -ForegroundColor Green
} else {
    Write-Host "[OK] Docker network 'evidentia_network' already exists" -ForegroundColor Green
}
Write-Host ""

# Start CouchDB containers
Write-Host "[INFO] Starting CouchDB containers..." -ForegroundColor Green
docker compose -f docker-compose-couch.yaml up -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to start CouchDB containers" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Waiting for CouchDB to be ready (10 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Verify CouchDB
$couchRunning = docker ps --filter "name=couchdb" --format "{{.Names}}"
if ($couchRunning) {
    Write-Host "[OK] CouchDB containers running:" -ForegroundColor Green
    $couchRunning | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
}
Write-Host ""

# Start Fabric network
Write-Host "[INFO] Starting Fabric containers..." -ForegroundColor Green
docker compose -f docker-compose-fabric.yaml up -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to start Fabric containers" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Waiting for Fabric network to stabilize (15 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Verify Fabric containers
$fabricRunning = docker ps --filter "label=service=hyperledger-fabric" --format "{{.Names}}"
if ($fabricRunning) {
    Write-Host "[OK] Fabric containers running:" -ForegroundColor Green
    $fabricRunning | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
}
Write-Host ""

# Start IPFS
Write-Host "[INFO] Starting IPFS node..." -ForegroundColor Green
docker compose -f docker-compose-ipfs.yaml up -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] Failed to start IPFS container (may already be running)" -ForegroundColor Yellow
}

Write-Host "[INFO] Waiting for IPFS to initialize (5 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Verify IPFS
$ipfsRunning = docker ps --filter "name=ipfs" --format "{{.Names}}"
if ($ipfsRunning) {
    Write-Host "[OK] IPFS container running: $ipfsRunning" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Network Started Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Services running:" -ForegroundColor White
Write-Host "  Orderer:              localhost:7050" -ForegroundColor Gray
Write-Host "  LawEnforcement Peer:  localhost:7051" -ForegroundColor Gray
Write-Host "  ForensicLab Peer:     localhost:9051" -ForegroundColor Gray
Write-Host "  Judiciary Peer:       localhost:11051" -ForegroundColor Gray
Write-Host "  CouchDB (LE):         localhost:5984" -ForegroundColor Gray
Write-Host "  CouchDB (FL):         localhost:6984" -ForegroundColor Gray
Write-Host "  CouchDB (JD):         localhost:7984" -ForegroundColor Gray
Write-Host "  IPFS API:             localhost:5001" -ForegroundColor Gray
Write-Host "  IPFS Gateway:         localhost:8080" -ForegroundColor Gray
Write-Host ""
Write-Host "View running containers:" -ForegroundColor Yellow
Write-Host "  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" -ForegroundColor Gray
Write-Host ""
Write-Host "Next step: Run .\scripts\Create-Channel.ps1" -ForegroundColor Yellow

