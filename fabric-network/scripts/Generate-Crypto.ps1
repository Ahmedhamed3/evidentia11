# Evidentia - Generate Crypto Materials Script for Windows
# This script generates all certificates and channel artifacts

param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
)

$ErrorActionPreference = "Stop"

# If ProjectRoot is not set correctly, try to find it
if (-not (Test-Path (Join-Path $ProjectRoot "fabric-network"))) {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

$NetworkDir = Join-Path $ProjectRoot "fabric-network"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Evidentia Crypto Material Generation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project Root: $ProjectRoot" -ForegroundColor Gray
Write-Host "Network Dir: $NetworkDir" -ForegroundColor Gray
Write-Host ""

# Change to network directory
Set-Location $NetworkDir

# Check prerequisites
Write-Host "[INFO] Checking prerequisites..." -ForegroundColor Green

$cryptogen = Get-Command cryptogen -ErrorAction SilentlyContinue
if (-not $cryptogen) {
    Write-Host "[ERROR] cryptogen not found in PATH." -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure Fabric binaries are installed and added to PATH:" -ForegroundColor Yellow
    Write-Host "  1. Download from: https://github.com/hyperledger/fabric/releases" -ForegroundColor Gray
    Write-Host "  2. Extract to C:\fabric\bin" -ForegroundColor Gray
    Write-Host "  3. Add C:\fabric\bin to your PATH environment variable" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

$configtxgen = Get-Command configtxgen -ErrorAction SilentlyContinue
if (-not $configtxgen) {
    Write-Host "[ERROR] configtxgen not found in PATH." -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Prerequisites check passed." -ForegroundColor Green
Write-Host "  - cryptogen: $($cryptogen.Source)" -ForegroundColor Gray
Write-Host "  - configtxgen: $($configtxgen.Source)" -ForegroundColor Gray
Write-Host ""

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
Write-Host "[INFO] Generating crypto materials using cryptogen..." -ForegroundColor Green

# Set FABRIC_CFG_PATH to current directory
$env:FABRIC_CFG_PATH = $NetworkDir

# Run cryptogen
$cryptogenArgs = @("generate", "--config=crypto-config.yaml", "--output=crypto-config")
& cryptogen $cryptogenArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to generate crypto materials" -ForegroundColor Red
    Write-Host "Please check that crypto-config.yaml exists and is valid." -ForegroundColor Yellow
    exit 1
}

Write-Host "[INFO] Crypto materials generated successfully." -ForegroundColor Green
Write-Host ""

# Generate genesis block
Write-Host "[INFO] Generating genesis block using configtxgen..." -ForegroundColor Green

$configtxgenArgs = @(
    "-profile", "EvidentiaCoCGenesis",
    "-outputBlock", ".\channel-artifacts\evidencechannel.block",
    "-channelID", "evidence-channel"
)
& configtxgen $configtxgenArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to generate genesis block" -ForegroundColor Red
    Write-Host "Please check that configtx.yaml exists and is valid." -ForegroundColor Yellow
    exit 1
}

Write-Host "[INFO] Channel artifacts generated successfully." -ForegroundColor Green

# Verify generated files
Write-Host ""
Write-Host "[INFO] Verifying generated files..." -ForegroundColor Green

$cryptoConfigExists = Test-Path "crypto-config\ordererOrganizations"
$peerOrgsExist = Test-Path "crypto-config\peerOrganizations"
$genesisExists = Test-Path "channel-artifacts\evidencechannel.block"

if ($cryptoConfigExists -and $peerOrgsExist -and $genesisExists) {
    Write-Host "[OK] All files generated successfully!" -ForegroundColor Green
} else {
    Write-Host "[WARN] Some files may be missing:" -ForegroundColor Yellow
    Write-Host "  - ordererOrganizations: $cryptoConfigExists" -ForegroundColor Gray
    Write-Host "  - peerOrganizations: $peerOrgsExist" -ForegroundColor Gray
    Write-Host "  - genesis block: $genesisExists" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Crypto Material Generation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Generated files:" -ForegroundColor White
Write-Host "  - crypto-config\ (certificates and keys)" -ForegroundColor Gray

# List organizations
$orgs = Get-ChildItem "crypto-config\peerOrganizations" -Directory -ErrorAction SilentlyContinue
if ($orgs) {
    foreach ($org in $orgs) {
        Write-Host "    - $($org.Name)" -ForegroundColor Gray
    }
}

Write-Host "  - channel-artifacts\ (genesis block)" -ForegroundColor Gray
Write-Host ""
Write-Host "Next step: Run .\scripts\Start-Network.ps1" -ForegroundColor Yellow

