# Evidentia - Create Channel Script for Windows
# This script creates the evidence channel and joins all peers

param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
)

$ErrorActionPreference = "Stop"

# If ProjectRoot is not set correctly, try to find it
if (-not (Test-Path (Join-Path $ProjectRoot "fabric-network"))) {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

$NetworkDir = Join-Path $ProjectRoot "fabric-network"
$ChannelName = "evidence-channel"
$Delay = 3

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Creating Evidence Channel" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Set-Location $NetworkDir

# Set FABRIC_CFG_PATH to the peercfg directory where core.yaml is located
$env:FABRIC_CFG_PATH = Join-Path $NetworkDir "peercfg"

Write-Host "[INFO] FABRIC_CFG_PATH set to: $env:FABRIC_CFG_PATH" -ForegroundColor Gray

# Check prerequisites
$osnadmin = Get-Command osnadmin -ErrorAction SilentlyContinue
if (-not $osnadmin) {
    Write-Host "[ERROR] osnadmin not found. Fabric binaries may not be installed." -ForegroundColor Red
    exit 1
}

# Paths for orderer TLS
$OrdererCA = Join-Path $NetworkDir "crypto-config\ordererOrganizations\evidentia.network\orderers\orderer.evidentia.network\msp\tlscacerts\tlsca.evidentia.network-cert.pem"
$OrdererCert = Join-Path $NetworkDir "crypto-config\ordererOrganizations\evidentia.network\orderers\orderer.evidentia.network\tls\server.crt"
$OrdererKey = Join-Path $NetworkDir "crypto-config\ordererOrganizations\evidentia.network\orderers\orderer.evidentia.network\tls\server.key"

# Check files exist
if (-not (Test-Path $OrdererCA)) {
    Write-Host "[ERROR] Orderer CA certificate not found." -ForegroundColor Red
    Write-Host "Path: $OrdererCA" -ForegroundColor Gray
    Write-Host "Please run Generate-Crypto.ps1 first." -ForegroundColor Yellow
    exit 1
}

# Create the channel
Write-Host "[INFO] Creating channel: $ChannelName" -ForegroundColor Green

$createChannelArgs = @(
    "channel", "join",
    "--channelID", $ChannelName,
    "--config-block", ".\channel-artifacts\evidencechannel.block",
    "-o", "localhost:7053",
    "--ca-file", $OrdererCA,
    "--client-cert", $OrdererCert,
    "--client-key", $OrdererKey
)

& osnadmin $createChannelArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to create channel" -ForegroundColor Red
    Write-Host "The channel may already exist, or the orderer may not be ready." -ForegroundColor Yellow
    Write-Host "Wait a few seconds and try again, or check orderer logs:" -ForegroundColor Yellow
    Write-Host "  docker logs orderer.evidentia.network" -ForegroundColor Gray
    exit 1
}

Write-Host "[OK] Channel $ChannelName created successfully" -ForegroundColor Green
Write-Host ""
Write-Host "[INFO] Waiting $Delay seconds..." -ForegroundColor Yellow
Start-Sleep -Seconds $Delay

# Function to join peer to channel
function Join-PeerToChannel {
    param(
        [string]$OrgName,
        [string]$MspId,
        [string]$PeerAddress,
        [int]$MaxRetries = 5
    )
    
    Write-Host "[INFO] Joining $OrgName peer to channel..." -ForegroundColor Green
    
    $OrgDomain = $OrgName.ToLower()
    
    # Set environment variables for peer CLI
    $env:CORE_PEER_LOCALMSPID = $MspId
    $env:CORE_PEER_TLS_ENABLED = "true"
    $env:CORE_PEER_TLS_ROOTCERT_FILE = Join-Path $NetworkDir "crypto-config\peerOrganizations\$OrgDomain.evidentia.network\peers\peer0.$OrgDomain.evidentia.network\tls\ca.crt"
    $env:CORE_PEER_MSPCONFIGPATH = Join-Path $NetworkDir "crypto-config\peerOrganizations\$OrgDomain.evidentia.network\users\Admin@$OrgDomain.evidentia.network\msp"
    $env:CORE_PEER_ADDRESS = $PeerAddress
    
    # Retry loop
    for ($i = 1; $i -le $MaxRetries; $i++) {
        $joinArgs = @(
            "channel", "join",
            "-b", ".\channel-artifacts\evidencechannel.block"
        )
        
        & peer $joinArgs 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] $OrgName peer joined channel successfully" -ForegroundColor Green
            return $true
        }
        
        if ($i -lt $MaxRetries) {
            Write-Host "[WARN] Join failed, retrying in $Delay seconds... (attempt $i/$MaxRetries)" -ForegroundColor Yellow
            Start-Sleep -Seconds $Delay
        }
    }
    
    Write-Host "[ERROR] Failed to join $OrgName peer after $MaxRetries attempts" -ForegroundColor Red
    return $false
}

# Join all peers
$success = Join-PeerToChannel -OrgName "LawEnforcement" -MspId "LawEnforcementMSP" -PeerAddress "localhost:7051"
Start-Sleep -Seconds $Delay

$success = Join-PeerToChannel -OrgName "ForensicLab" -MspId "ForensicLabMSP" -PeerAddress "localhost:9051"
Start-Sleep -Seconds $Delay

$success = Join-PeerToChannel -OrgName "Judiciary" -MspId "JudiciaryMSP" -PeerAddress "localhost:11051"

Write-Host ""

# List channels to verify
Write-Host "[INFO] Verifying channel membership..." -ForegroundColor Green

# Check with orderer
$listArgs = @(
    "channel", "list",
    "-o", "localhost:7053",
    "--ca-file", $OrdererCA,
    "--client-cert", $OrdererCert,
    "--client-key", $OrdererKey
)

& osnadmin $listArgs

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Channel Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Channel: $ChannelName" -ForegroundColor Gray
Write-Host "Peers joined:" -ForegroundColor Gray
Write-Host "  - peer0.lawenforcement.evidentia.network:7051" -ForegroundColor Gray
Write-Host "  - peer0.forensiclab.evidentia.network:9051" -ForegroundColor Gray
Write-Host "  - peer0.judiciary.evidentia.network:11051" -ForegroundColor Gray
Write-Host ""
Write-Host "Next step: Run .\scripts\Deploy-Chaincode.ps1" -ForegroundColor Yellow

