# Evidentia - Deploy Chaincode Script for Windows
# This script packages, installs, approves, and commits the chaincode

param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
)

# Note: We use "Continue" instead of "Stop" because Fabric CLI outputs INFO messages to stderr
# which PowerShell incorrectly treats as errors
$ErrorActionPreference = "Continue"

# If ProjectRoot is not set correctly, try to find it
if (-not (Test-Path (Join-Path $ProjectRoot "fabric-network"))) {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

$NetworkDir = Join-Path $ProjectRoot "fabric-network"
$ChaincodeDir = Join-Path $ProjectRoot "chaincode\evidence-coc"
$ChannelName = "evidence-channel"
$ChaincodeName = "evidence-coc"
$ChaincodeVersion = "1.0"
$ChaincodeSequence = 1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deploying Evidence CoC Chaincode" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Chaincode: $ChaincodeName v$ChaincodeVersion" -ForegroundColor Gray
Write-Host "Channel: $ChannelName" -ForegroundColor Gray
Write-Host ""

Set-Location $NetworkDir

# Set FABRIC_CFG_PATH to the peercfg directory where core.yaml is located
# Use forward slashes for compatibility
$env:FABRIC_CFG_PATH = (Join-Path $NetworkDir "peercfg").Replace('\', '/')
Write-Host "[INFO] FABRIC_CFG_PATH: $env:FABRIC_CFG_PATH" -ForegroundColor Gray
Write-Host "[INFO] NetworkDir: $NetworkDir" -ForegroundColor Gray

# Check Go is installed
$goCmd = Get-Command go -ErrorAction SilentlyContinue
if (-not $goCmd) {
    Write-Host "[ERROR] Go is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# Check chaincode directory exists
if (-not (Test-Path $ChaincodeDir)) {
    Write-Host "[ERROR] Chaincode directory not found: $ChaincodeDir" -ForegroundColor Red
    exit 1
}

# Check if peers are running
Write-Host "[INFO] Checking if Fabric peers are running..." -ForegroundColor Green
$peerContainers = docker ps --filter "name=peer0" --format "{{.Names}}" 2>$null
if (-not $peerContainers) {
    Write-Host "[ERROR] No peer containers are running!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please start the network first:" -ForegroundColor Yellow
    Write-Host "  cd fabric-network\docker" -ForegroundColor Gray
    Write-Host "  docker compose -f docker-compose-couch.yaml up -d" -ForegroundColor Gray
    Write-Host "  docker compose -f docker-compose-fabric.yaml up -d" -ForegroundColor Gray
    Write-Host ""
    exit 1
}
Write-Host "[OK] Found running peers: $($peerContainers -join ', ')" -ForegroundColor Green

# Vendor Go modules
Write-Host "[INFO] Vendoring Go modules..." -ForegroundColor Green
Set-Location $ChaincodeDir
$env:GO111MODULE = "on"
$env:GOFLAGS = "-mod=mod"

& go mod tidy 2>&1 | Out-Null
& go mod vendor 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to vendor Go modules" -ForegroundColor Red
    Write-Host "Try running 'go mod tidy' manually in the chaincode directory." -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] Go modules vendored" -ForegroundColor Green
Set-Location $NetworkDir

# Helper to set peer environment
function Set-PeerEnv {
    param(
        [string]$OrgName,
        [string]$MspId,
        [string]$PeerAddress
    )
    
    $OrgDomain = $OrgName.ToLower()
    
    # Use forward slashes for paths - peer CLI handles them better
    $tlsCert = (Join-Path $NetworkDir "crypto-config\peerOrganizations\$OrgDomain.evidentia.network\peers\peer0.$OrgDomain.evidentia.network\tls\ca.crt").Replace('\', '/')
    $mspPath = (Join-Path $NetworkDir "crypto-config\peerOrganizations\$OrgDomain.evidentia.network\users\Admin@$OrgDomain.evidentia.network\msp").Replace('\', '/')
    
    $env:CORE_PEER_LOCALMSPID = $MspId
    $env:CORE_PEER_TLS_ENABLED = "true"
    $env:CORE_PEER_TLS_ROOTCERT_FILE = $tlsCert
    $env:CORE_PEER_MSPCONFIGPATH = $mspPath
    $env:CORE_PEER_ADDRESS = $PeerAddress
}

# Package chaincode
Write-Host ""
Write-Host "[INFO] Packaging chaincode..." -ForegroundColor Green

Set-PeerEnv -OrgName "LawEnforcement" -MspId "LawEnforcementMSP" -PeerAddress "localhost:7051"

# Remove old package if exists
if (Test-Path "$ChaincodeName.tar.gz") {
    Remove-Item "$ChaincodeName.tar.gz"
}

# Use forward slashes for chaincode path
$ChaincodeDirForward = $ChaincodeDir.Replace('\', '/')

$packageArgs = @(
    "lifecycle", "chaincode", "package",
    "$ChaincodeName.tar.gz",
    "--path", $ChaincodeDirForward,
    "--lang", "golang",
    "--label", "${ChaincodeName}_${ChaincodeVersion}"
)

& peer $packageArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to package chaincode" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Chaincode packaged: $ChaincodeName.tar.gz" -ForegroundColor Green

# Install on all peers
$orgs = @(
    @{Name="LawEnforcement"; MspId="LawEnforcementMSP"; Address="localhost:7051"},
    @{Name="ForensicLab"; MspId="ForensicLabMSP"; Address="localhost:9051"},
    @{Name="Judiciary"; MspId="JudiciaryMSP"; Address="localhost:11051"}
)

Write-Host ""
Write-Host "[INFO] Installing chaincode on peers..." -ForegroundColor Green

foreach ($org in $orgs) {
    Write-Host "  Installing on $($org.Name)..." -ForegroundColor Gray
    Set-PeerEnv -OrgName $org.Name -MspId $org.MspId -PeerAddress $org.Address
    
    $installArgs = @("lifecycle", "chaincode", "install", "$ChaincodeName.tar.gz")
    $installOutput = & peer $installArgs 2>&1 | Out-String
    
    # Check for success - peer CLI returns 0 on success but also check output for package ID
    if ($LASTEXITCODE -ne 0 -and $installOutput -notmatch "Chaincode code package identifier") {
        Write-Host "[ERROR] Failed to install on $($org.Name)" -ForegroundColor Red
        Write-Host "Error details:" -ForegroundColor Yellow
        Write-Host $installOutput -ForegroundColor Gray
        exit 1
    }
    Write-Host "  [OK] Installed on $($org.Name)" -ForegroundColor Green
}

# Get package ID
Write-Host ""
Write-Host "[INFO] Getting package ID..." -ForegroundColor Green

Set-PeerEnv -OrgName "LawEnforcement" -MspId "LawEnforcementMSP" -PeerAddress "localhost:7051"

$queryOutput = & peer lifecycle chaincode queryinstalled 2>&1
$packageIdMatch = [regex]::Match($queryOutput, "Package ID: (${ChaincodeName}_${ChaincodeVersion}:[a-f0-9]+)")

if (-not $packageIdMatch.Success) {
    Write-Host "[ERROR] Failed to get package ID" -ForegroundColor Red
    Write-Host "Query output: $queryOutput" -ForegroundColor Gray
    exit 1
}

$PackageId = $packageIdMatch.Groups[1].Value
Write-Host "[OK] Package ID: $PackageId" -ForegroundColor Green

# Approve for all orgs
Write-Host ""
Write-Host "[INFO] Approving chaincode for organizations..." -ForegroundColor Green

# Use forward slashes for paths
$OrdererCA = (Join-Path $NetworkDir "crypto-config\ordererOrganizations\evidentia.network\orderers\orderer.evidentia.network\msp\tlscacerts\tlsca.evidentia.network-cert.pem").Replace('\', '/')
$CollectionsConfig = Join-Path $NetworkDir "collections_config.json"

foreach ($org in $orgs) {
    Write-Host "  Approving for $($org.Name)..." -ForegroundColor Gray
    Set-PeerEnv -OrgName $org.Name -MspId $org.MspId -PeerAddress $org.Address
    
    $approveArgs = @(
        "lifecycle", "chaincode", "approveformyorg",
        "-o", "localhost:7050",
        "--ordererTLSHostnameOverride", "orderer.evidentia.network",
        "--channelID", $ChannelName,
        "--name", $ChaincodeName,
        "--version", $ChaincodeVersion,
        "--package-id", $PackageId,
        "--sequence", $ChaincodeSequence,
        "--tls",
        "--cafile", $OrdererCA
    )
    
    if (Test-Path $CollectionsConfig) {
        $approveArgs += "--collections-config"
        $approveArgs += $CollectionsConfig
    }
    
    $approveOutput = & peer $approveArgs 2>&1 | Out-String
    
    if ($LASTEXITCODE -ne 0 -and $approveOutput -notmatch "committed with status") {
        Write-Host "[ERROR] Failed to approve for $($org.Name)" -ForegroundColor Red
        Write-Host "Error details:" -ForegroundColor Yellow
        Write-Host $approveOutput -ForegroundColor Gray
        exit 1
    }
    Write-Host "  [OK] Approved for $($org.Name)" -ForegroundColor Green
}

# Check commit readiness
Write-Host ""
Write-Host "[INFO] Checking commit readiness..." -ForegroundColor Green

Set-PeerEnv -OrgName "LawEnforcement" -MspId "LawEnforcementMSP" -PeerAddress "localhost:7051"

$checkArgs = @(
    "lifecycle", "chaincode", "checkcommitreadiness",
    "--channelID", $ChannelName,
    "--name", $ChaincodeName,
    "--version", $ChaincodeVersion,
    "--sequence", $ChaincodeSequence,
    "--tls",
    "--cafile", $OrdererCA,
    "--output", "json"
)

if (Test-Path $CollectionsConfig) {
    $checkArgs += "--collections-config"
    $checkArgs += $CollectionsConfig
}

& peer $checkArgs

# Commit chaincode
Write-Host ""
Write-Host "[INFO] Committing chaincode to channel..." -ForegroundColor Green

# Use forward slashes for paths
$LE_CA = (Join-Path $NetworkDir "crypto-config\peerOrganizations\lawenforcement.evidentia.network\peers\peer0.lawenforcement.evidentia.network\tls\ca.crt").Replace('\', '/')
$FL_CA = (Join-Path $NetworkDir "crypto-config\peerOrganizations\forensiclab.evidentia.network\peers\peer0.forensiclab.evidentia.network\tls\ca.crt").Replace('\', '/')
$JD_CA = (Join-Path $NetworkDir "crypto-config\peerOrganizations\judiciary.evidentia.network\peers\peer0.judiciary.evidentia.network\tls\ca.crt").Replace('\', '/')

$commitArgs = @(
    "lifecycle", "chaincode", "commit",
    "-o", "localhost:7050",
    "--ordererTLSHostnameOverride", "orderer.evidentia.network",
    "--channelID", $ChannelName,
    "--name", $ChaincodeName,
    "--version", $ChaincodeVersion,
    "--sequence", $ChaincodeSequence,
    "--tls",
    "--cafile", $OrdererCA,
    "--peerAddresses", "localhost:7051",
    "--tlsRootCertFiles", $LE_CA,
    "--peerAddresses", "localhost:9051",
    "--tlsRootCertFiles", $FL_CA,
    "--peerAddresses", "localhost:11051",
    "--tlsRootCertFiles", $JD_CA
)

if (Test-Path $CollectionsConfig) {
    $commitArgs += "--collections-config"
    $commitArgs += $CollectionsConfig
}

& peer $commitArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to commit chaincode" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Chaincode committed successfully" -ForegroundColor Green

# Query committed
Write-Host ""
Write-Host "[INFO] Verifying committed chaincode..." -ForegroundColor Green

$queryCommittedArgs = @(
    "lifecycle", "chaincode", "querycommitted",
    "--channelID", $ChannelName,
    "--name", $ChaincodeName
)

& peer $queryCommittedArgs

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Chaincode Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Chaincode: $ChaincodeName" -ForegroundColor Gray
Write-Host "Version: $ChaincodeVersion" -ForegroundColor Gray
Write-Host "Sequence: $ChaincodeSequence" -ForegroundColor Gray
Write-Host "Channel: $ChannelName" -ForegroundColor Gray
Write-Host ""
Write-Host "The chaincode is now ready for use." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Start backend: cd backend && npm run dev" -ForegroundColor Gray
Write-Host "  2. Start frontend: cd frontend && npm start" -ForegroundColor Gray

