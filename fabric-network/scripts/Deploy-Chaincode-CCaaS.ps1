# Evidentia - Deploy Chaincode using CCaaS (Chaincode-as-a-Service)
# This approach avoids Docker-in-Docker issues on Windows

param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
)

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
$ChaincodePort = 9999

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deploying Chaincode (CCaaS Mode)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Chaincode: $ChaincodeName v$ChaincodeVersion" -ForegroundColor Gray
Write-Host "Channel: $ChannelName" -ForegroundColor Gray
Write-Host "Mode: Chaincode-as-a-Service (external)" -ForegroundColor Gray
Write-Host ""

Set-Location $NetworkDir

$env:FABRIC_CFG_PATH = (Join-Path $NetworkDir "peercfg").Replace('\', '/')

# Check if peers are running
Write-Host "[INFO] Checking if Fabric peers are running..." -ForegroundColor Green
$peerContainers = docker ps --filter "name=peer0" --format "{{.Names}}" 2>$null
if (-not $peerContainers) {
    Write-Host "[ERROR] No peer containers are running!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Found running peers" -ForegroundColor Green

# Step 1: Build chaincode Docker image
Write-Host ""
Write-Host "[INFO] Building chaincode Docker image..." -ForegroundColor Green

Set-Location $ChaincodeDir

# Build the image
docker build -t evidentia-chaincode:$ChaincodeVersion .

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to build chaincode image" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Chaincode image built: evidentia-chaincode:$ChaincodeVersion" -ForegroundColor Green

Set-Location $NetworkDir

# Step 2: Create CCaaS package
Write-Host ""
Write-Host "[INFO] Creating CCaaS package..." -ForegroundColor Green

# Create temp directory for package
$PackageDir = Join-Path $NetworkDir "ccaas-package"
if (Test-Path $PackageDir) {
    Remove-Item -Recurse -Force $PackageDir
}
New-Item -ItemType Directory -Path $PackageDir | Out-Null

# Create connection.json - chaincode will connect to peer
$connectionJson = @{
    address = "evidentia-chaincode:$ChaincodePort"
    dial_timeout = "10s"
    tls_required = $false
} | ConvertTo-Json

# Use .NET method to write UTF-8 without BOM (PowerShell's Out-File adds BOM on Windows)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $PackageDir "connection.json"), $connectionJson, $utf8NoBom)

# Create metadata.json
$metadataJson = @{
    type = "ccaas"
    label = "${ChaincodeName}_${ChaincodeVersion}"
} | ConvertTo-Json

[System.IO.File]::WriteAllText((Join-Path $PackageDir "metadata.json"), $metadataJson, $utf8NoBom)

# Create code.tar.gz (contains connection.json)
Set-Location $PackageDir
tar -czf code.tar.gz connection.json

# Create the final package
tar -czf "$ChaincodeName.tar.gz" metadata.json code.tar.gz

# Move package to network dir
Move-Item -Force "$ChaincodeName.tar.gz" $NetworkDir

Set-Location $NetworkDir
Remove-Item -Recurse -Force $PackageDir

Write-Host "[OK] CCaaS package created: $ChaincodeName.tar.gz" -ForegroundColor Green

# Helper to set peer environment
function Set-PeerEnv {
    param(
        [string]$OrgName,
        [string]$MspId,
        [string]$PeerAddress
    )
    
    $OrgDomain = $OrgName.ToLower()
    $tlsCert = (Join-Path $NetworkDir "crypto-config\peerOrganizations\$OrgDomain.evidentia.network\peers\peer0.$OrgDomain.evidentia.network\tls\ca.crt").Replace('\', '/')
    $mspPath = (Join-Path $NetworkDir "crypto-config\peerOrganizations\$OrgDomain.evidentia.network\users\Admin@$OrgDomain.evidentia.network\msp").Replace('\', '/')
    
    $env:CORE_PEER_LOCALMSPID = $MspId
    $env:CORE_PEER_TLS_ENABLED = "true"
    $env:CORE_PEER_TLS_ROOTCERT_FILE = $tlsCert
    $env:CORE_PEER_MSPCONFIGPATH = $mspPath
    $env:CORE_PEER_ADDRESS = $PeerAddress
}

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
    
    $installOutput = & peer lifecycle chaincode install "$ChaincodeName.tar.gz" 2>&1 | Out-String
    
    if ($LASTEXITCODE -ne 0 -and $installOutput -notmatch "Chaincode code package identifier") {
        Write-Host "[ERROR] Failed to install on $($org.Name)" -ForegroundColor Red
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

# Step 3: Start chaincode container
Write-Host ""
Write-Host "[INFO] Starting chaincode container..." -ForegroundColor Green

# Stop existing chaincode container if running
docker rm -f evidentia-chaincode 2>$null

# Start chaincode container
# The chaincode needs CHAINCODE_ID and CHAINCODE_SERVER_ADDRESS
docker run -d `
    --name evidentia-chaincode `
    --network evidentia_network `
    -e CHAINCODE_ID=$PackageId `
    -e CHAINCODE_SERVER_ADDRESS=0.0.0.0:$ChaincodePort `
    -p ${ChaincodePort}:${ChaincodePort} `
    evidentia-chaincode:$ChaincodeVersion

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to start chaincode container" -ForegroundColor Red
    exit 1
}

# Wait for chaincode to start
Start-Sleep -Seconds 5

# Check if running
$ccRunning = docker ps --filter "name=evidentia-chaincode" --format "{{.Names}}"
if (-not $ccRunning) {
    Write-Host "[ERROR] Chaincode container is not running" -ForegroundColor Red
    docker logs evidentia-chaincode
    exit 1
}

Write-Host "[OK] Chaincode container started" -ForegroundColor Green

# Approve for all orgs
Write-Host ""
Write-Host "[INFO] Approving chaincode for organizations..." -ForegroundColor Green

$OrdererCA = (Join-Path $NetworkDir "crypto-config\ordererOrganizations\evidentia.network\orderers\orderer.evidentia.network\msp\tlscacerts\tlsca.evidentia.network-cert.pem").Replace('\', '/')

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
    
    $approveOutput = & peer $approveArgs 2>&1 | Out-String
    
    if ($LASTEXITCODE -ne 0 -and $approveOutput -notmatch "committed with status") {
        Write-Host "[ERROR] Failed to approve for $($org.Name)" -ForegroundColor Red
        Write-Host $approveOutput -ForegroundColor Gray
        exit 1
    }
    Write-Host "  [OK] Approved for $($org.Name)" -ForegroundColor Green
}

# Commit chaincode
Write-Host ""
Write-Host "[INFO] Committing chaincode to channel..." -ForegroundColor Green

Set-PeerEnv -OrgName "LawEnforcement" -MspId "LawEnforcementMSP" -PeerAddress "localhost:7051"

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

& peer $commitArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to commit chaincode" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Chaincode committed successfully" -ForegroundColor Green

# Query committed
Write-Host ""
Write-Host "[INFO] Verifying committed chaincode..." -ForegroundColor Green

& peer lifecycle chaincode querycommitted --channelID $ChannelName --name $ChaincodeName

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Chaincode Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Chaincode: $ChaincodeName" -ForegroundColor Gray
Write-Host "Version: $ChaincodeVersion" -ForegroundColor Gray
Write-Host "Mode: CCaaS (Chaincode-as-a-Service)" -ForegroundColor Gray
Write-Host ""
Write-Host "Chaincode container: evidentia-chaincode" -ForegroundColor Gray
Write-Host "To view logs: docker logs evidentia-chaincode" -ForegroundColor Gray
Write-Host ""

