# Evidentia - Stop All Services Script for Windows
# This script stops all Evidentia services

param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [switch]$Clean
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Evidentia - Stop All Services" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Kill Node.js processes (backend/frontend)
Write-Host "[INFO] Stopping Node.js processes..." -ForegroundColor Yellow

$nodeProcesses = Get-Process -Name node -ErrorAction SilentlyContinue
if ($nodeProcesses) {
    $nodeProcesses | ForEach-Object {
        $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)").CommandLine
        if ($cmdLine -like "*evidentia*" -or $cmdLine -like "*3000*" -or $cmdLine -like "*3001*") {
            Write-Host "  Stopping PID $($_.Id)..." -ForegroundColor Gray
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "[OK] Node.js processes stopped" -ForegroundColor Green
} else {
    Write-Host "[OK] No Node.js processes found" -ForegroundColor Green
}

# Stop Fabric network
Write-Host "[INFO] Stopping Fabric network..." -ForegroundColor Yellow

$stopScript = Join-Path $ProjectRoot "fabric-network\scripts\Stop-Network.ps1"
if (Test-Path $stopScript) {
    if ($Clean) {
        & $stopScript -Clean
    } else {
        & $stopScript
    }
} else {
    # Manual stop if script not found
    $dockerDir = Join-Path $ProjectRoot "fabric-network\docker"
    if (Test-Path $dockerDir) {
        Set-Location $dockerDir
        docker compose -f docker-compose-ipfs.yaml down 2>$null
        docker compose -f docker-compose-fabric.yaml down 2>$null
        docker compose -f docker-compose-couch.yaml down 2>$null
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  All Services Stopped" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

if ($Clean) {
    Write-Host "Clean mode: All generated files removed." -ForegroundColor Gray
    Write-Host "Run the following to restart fresh:" -ForegroundColor Yellow
    Write-Host "  .\fabric-network\scripts\Generate-Crypto.ps1" -ForegroundColor Gray
    Write-Host "  .\scripts\Start-All.ps1" -ForegroundColor Gray
} else {
    Write-Host "To restart, run:" -ForegroundColor Yellow
    Write-Host "  .\scripts\Start-All.ps1" -ForegroundColor Gray
}

