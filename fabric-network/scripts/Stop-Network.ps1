# Evidentia - Stop Network Script for Windows
# This script stops all Docker containers for the Fabric network

param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))),
    [switch]$RemoveVolumes,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

# If ProjectRoot is not set correctly, try to find it
if (-not (Test-Path (Join-Path $ProjectRoot "fabric-network"))) {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

$NetworkDir = Join-Path $ProjectRoot "fabric-network"
$DockerDir = Join-Path $NetworkDir "docker"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Stopping Evidentia Network" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Set-Location $DockerDir

# Build down command arguments
$downArgs = @("down")
if ($RemoveVolumes -or $Clean) {
    $downArgs += "--volumes"
}
$downArgs += "--remove-orphans"

# Stop IPFS
Write-Host "[INFO] Stopping IPFS..." -ForegroundColor Green
try {
    docker compose -f docker-compose-ipfs.yaml $downArgs 2>$null
} catch {
    Write-Host "[WARN] IPFS may not have been running" -ForegroundColor Yellow
}

# Stop Fabric network
Write-Host "[INFO] Stopping Fabric containers..." -ForegroundColor Green
try {
    docker compose -f docker-compose-fabric.yaml $downArgs 2>$null
} catch {
    Write-Host "[WARN] Fabric containers may not have been running" -ForegroundColor Yellow
}

# Stop CouchDB
Write-Host "[INFO] Stopping CouchDB containers..." -ForegroundColor Green
try {
    docker compose -f docker-compose-couch.yaml $downArgs 2>$null
} catch {
    Write-Host "[WARN] CouchDB containers may not have been running" -ForegroundColor Yellow
}

# Remove chaincode containers if any
Write-Host "[INFO] Removing chaincode containers..." -ForegroundColor Green
$ccContainers = docker ps -aq --filter "name=dev-peer" 2>$null
if ($ccContainers) {
    docker rm -f $ccContainers 2>$null
}

$cocContainers = docker ps -aq --filter "name=evidence-coc" 2>$null
if ($cocContainers) {
    docker rm -f $cocContainers 2>$null
}

# Clean mode - remove crypto materials and chaincode images
if ($Clean) {
    Write-Host ""
    Write-Host "[WARN] Clean mode: Removing all generated artifacts..." -ForegroundColor Yellow
    
    # Remove chaincode images
    Write-Host "[INFO] Removing chaincode images..." -ForegroundColor Green
    $ccImages = docker images -q --filter "reference=dev-peer*" 2>$null
    if ($ccImages) {
        docker rmi -f $ccImages 2>$null
    }
    
    # Remove crypto materials
    Set-Location $NetworkDir
    if (Test-Path "crypto-config") {
        Write-Host "[INFO] Removing crypto-config..." -ForegroundColor Green
        Remove-Item -Recurse -Force "crypto-config"
    }
    
    if (Test-Path "channel-artifacts") {
        Write-Host "[INFO] Removing channel-artifacts..." -ForegroundColor Green
        Remove-Item -Recurse -Force "channel-artifacts"
    }
    
    # Remove chaincode package
    if (Test-Path "evidence-coc.tar.gz") {
        Remove-Item -Force "evidence-coc.tar.gz"
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Network Stopped!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

if ($Clean) {
    Write-Host "All containers stopped and artifacts removed." -ForegroundColor Gray
    Write-Host ""
    Write-Host "To start fresh, run:" -ForegroundColor Yellow
    Write-Host "  .\scripts\Generate-Crypto.ps1" -ForegroundColor Gray
    Write-Host "  .\scripts\Start-Network.ps1" -ForegroundColor Gray
    Write-Host "  .\scripts\Create-Channel.ps1" -ForegroundColor Gray
    Write-Host "  .\scripts\Deploy-Chaincode.ps1" -ForegroundColor Gray
} else {
    Write-Host "All containers stopped." -ForegroundColor Gray
    Write-Host ""
    Write-Host "To restart, run:" -ForegroundColor Yellow
    Write-Host "  .\scripts\Start-Network.ps1" -ForegroundColor Gray
}

