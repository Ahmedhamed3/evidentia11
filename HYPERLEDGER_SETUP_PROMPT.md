# Hyperledger Fabric Setup Prompt for AI Assistant

## MISSION
You are tasked with setting up a complete Hyperledger Fabric blockchain network on Windows 11 for a new project. This setup must replicate the exact configuration and workflow used in the Evidentia project. Follow ALL steps precisely, including WSL2 configuration, Docker setup, Fabric binaries installation, network configuration, and chaincode deployment.

---

## CONTEXT: What We're Building

We need a **multi-organization Hyperledger Fabric network** with:
- **3 Peer Organizations**: LawEnforcement, ForensicLab, Judiciary
- **1 Orderer Organization**: OrdererOrg
- **1 Channel**: evidence-channel (shared by all organizations)
- **CouchDB** as state database (one per organization)
- **Chaincode** written in Go
- **Windows 11** environment using **WSL2** and **Docker Desktop**

---

## PART 1: PREREQUISITES & WSL2 SETUP

### Step 1.1: Enable WSL2 on Windows 11

**CRITICAL**: Hyperledger Fabric requires Linux. On Windows, we use WSL2 (Windows Subsystem for Linux 2) which Docker Desktop uses.

**Commands to run in PowerShell (as Administrator):**

```powershell
# Enable WSL feature
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

# Enable Virtual Machine Platform
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# RESTART COMPUTER REQUIRED
Restart-Computer
```

**After restart (PowerShell as Administrator):**

```powershell
# Set WSL2 as default version
wsl --set-default-version 2

# Install Ubuntu (optional but recommended)
wsl --install -d Ubuntu-22.04

# Verify WSL2 installation
wsl --list --verbose
# Expected output: VERSION column should show "2"
```

### Step 1.2: Install Docker Desktop for Windows

1. **Download**: https://www.docker.com/products/docker-desktop/
2. **Install** with these options:
   - ✅ Check "Use WSL 2 instead of Hyper-V"
   - ✅ Check "Add shortcut to desktop"
3. **After installation**, configure Docker Desktop:
   - **General** → Ensure "Use the WSL 2 based engine" is checked
   - **Resources** → **WSL Integration** → Enable integration with default WSL distro
   - **Resources** → **Advanced** → Set Memory to at least **8 GB** (8192 MB), CPUs to at least **4**
   - Click **Apply & restart**

**Verify Docker:**

```powershell
docker --version
docker compose version
docker run hello-world
```

### Step 1.3: Install Required Software

**Git:**
- Download: https://git-scm.com/download/win
- Install with default options
- Verify: `git --version`

**Node.js:**
- Download: https://nodejs.org/ (LTS version)
- Install with default options
- Verify: `node --version` and `npm --version`

**Go Programming Language:**
- Download: https://go.dev/dl/ (Windows installer, e.g., go1.21.5.windows-amd64.msi)
- Install to default location: `C:\Program Files\Go\`
- Verify: `go version` (must open NEW PowerShell window after installation)

---

## PART 2: HYPERLEDGER FABRIC BINARIES INSTALLATION

### Step 2.1: Create Fabric Directory Structure

```powershell
# Create directory for Fabric binaries
New-Item -ItemType Directory -Path "C:\fabric" -Force
New-Item -ItemType Directory -Path "C:\fabric\bin" -Force
New-Item -ItemType Directory -Path "C:\fabric\config" -Force
Set-Location -Path "C:\fabric"
```

### Step 2.2: Download Hyperledger Fabric Binaries

**Fabric Version**: 2.5.4 (or latest 2.5.x)
**Fabric CA Version**: 1.5.7

```powershell
$fabricVersion = "2.5.4"
$caVersion = "1.5.7"

# Download Fabric binaries
$url = "https://github.com/hyperledger/fabric/releases/download/v$fabricVersion/hyperledger-fabric-windows-amd64-$fabricVersion.zip"
$zipFile = "C:\fabric\fabric.zip"
Invoke-WebRequest -Uri $url -OutFile $zipFile
Expand-Archive -Path $zipFile -DestinationPath "C:\fabric" -Force
Remove-Item $zipFile

# Download Fabric CA binaries
$caUrl = "https://github.com/hyperledger/fabric-ca/releases/download/v$caVersion/hyperledger-fabric-ca-windows-amd64-$caVersion.zip"
$caZip = "C:\fabric\fabric-ca.zip"
Invoke-WebRequest -Uri $caUrl -OutFile $caZip
Expand-Archive -Path $caZip -DestinationPath "C:\fabric" -Force
Remove-Item $caZip

# Verify binaries exist
Get-ChildItem "C:\fabric\bin"
# Should see: configtxgen.exe, cryptogen.exe, peer.exe, orderer.exe, osnadmin.exe, etc.
```

### Step 2.3: Pull Required Docker Images

```powershell
# Pull all required Fabric Docker images
docker pull hyperledger/fabric-peer:2.5
docker pull hyperledger/fabric-orderer:2.5
docker pull hyperledger/fabric-tools:2.5
docker pull hyperledger/fabric-ccenv:2.5
docker pull hyperledger/fabric-baseos:2.5
docker pull hyperledger/fabric-ca:1.5
docker pull couchdb:3.3
docker pull ipfs/kubo:v0.24.0

# This will take 10-20 minutes depending on internet speed
```

### Step 2.4: Configure Windows Environment Variables

**CRITICAL**: Fabric binaries must be in PATH.

1. **Open Environment Variables**:
   - Press `Windows + R`
   - Type `sysdm.cpl` and press Enter
   - Click **Advanced** tab → **Environment Variables**

2. **Add to PATH** (System variables → Path → Edit):
   - `C:\fabric\bin`
   - `C:\Program Files\Go\bin`

3. **Add FABRIC_CFG_PATH** (System variables → New):
   - Variable name: `FABRIC_CFG_PATH`
   - Variable value: `C:\fabric\config`

4. **Close ALL PowerShell windows** and open a new one to pick up changes

5. **Verify PATH configuration:**

```powershell
peer version
configtxgen --version
cryptogen --help
```

---

## PART 3: PROJECT STRUCTURE & CONFIGURATION FILES

### Step 3.1: Create Project Directory Structure

```powershell
# Create project root (adjust path as needed)
$ProjectRoot = "C:\Projects\YourProjectName"
New-Item -ItemType Directory -Path $ProjectRoot -Force
Set-Location $ProjectRoot

# Create directory structure
New-Item -ItemType Directory -Path "fabric-network" -Force
New-Item -ItemType Directory -Path "fabric-network\docker" -Force
New-Item -ItemType Directory -Path "fabric-network\scripts" -Force
New-Item -ItemType Directory -Path "fabric-network\peercfg" -Force
New-Item -ItemType Directory -Path "chaincode\your-chaincode-name" -Force
```

### Step 3.2: Create crypto-config.yaml

**File**: `fabric-network/crypto-config.yaml`

```yaml
OrdererOrgs:
  - Name: Orderer
    Domain: evidentia.network
    EnableNodeOUs: true
    Specs:
      - Hostname: orderer
        SANS:
          - localhost
          - 127.0.0.1

PeerOrgs:
  - Name: LawEnforcement
    Domain: lawenforcement.evidentia.network
    EnableNodeOUs: true
    Template:
      Count: 1
      SANS:
        - localhost
        - 127.0.0.1
    Users:
      Count: 3

  - Name: ForensicLab
    Domain: forensiclab.evidentia.network
    EnableNodeOUs: true
    Template:
      Count: 1
      SANS:
        - localhost
        - 127.0.0.1
    Users:
      Count: 3

  - Name: Judiciary
    Domain: judiciary.evidentia.network
    EnableNodeOUs: true
    Template:
      Count: 1
      SANS:
        - localhost
        - 127.0.0.1
    Users:
      Count: 3
```

**IMPORTANT**: Adjust domain names (`evidentia.network` → your domain) and organization names as needed for your project.

### Step 3.3: Create configtx.yaml

**File**: `fabric-network/configtx.yaml`

```yaml
Organizations:
  - &OrdererOrg
    Name: OrdererOrg
    ID: OrdererMSP
    MSPDir: crypto-config/ordererOrganizations/evidentia.network/msp
    Policies:
      Readers:
        Type: Signature
        Rule: "OR('OrdererMSP.member')"
      Writers:
        Type: Signature
        Rule: "OR('OrdererMSP.member')"
      Admins:
        Type: Signature
        Rule: "OR('OrdererMSP.admin')"
    OrdererEndpoints:
      - orderer.evidentia.network:7050

  - &LawEnforcementOrg
    Name: LawEnforcementOrg
    ID: LawEnforcementMSP
    MSPDir: crypto-config/peerOrganizations/lawenforcement.evidentia.network/msp
    Policies:
      Readers:
        Type: Signature
        Rule: "OR('LawEnforcementMSP.admin', 'LawEnforcementMSP.peer', 'LawEnforcementMSP.client')"
      Writers:
        Type: Signature
        Rule: "OR('LawEnforcementMSP.admin', 'LawEnforcementMSP.client')"
      Admins:
        Type: Signature
        Rule: "OR('LawEnforcementMSP.admin')"
      Endorsement:
        Type: Signature
        Rule: "OR('LawEnforcementMSP.peer')"
    AnchorPeers:
      - Host: peer0.lawenforcement.evidentia.network
        Port: 7051

  - &ForensicLabOrg
    Name: ForensicLabOrg
    ID: ForensicLabMSP
    MSPDir: crypto-config/peerOrganizations/forensiclab.evidentia.network/msp
    Policies:
      Readers:
        Type: Signature
        Rule: "OR('ForensicLabMSP.admin', 'ForensicLabMSP.peer', 'ForensicLabMSP.client')"
      Writers:
        Type: Signature
        Rule: "OR('ForensicLabMSP.admin', 'ForensicLabMSP.client')"
      Admins:
        Type: Signature
        Rule: "OR('ForensicLabMSP.admin')"
      Endorsement:
        Type: Signature
        Rule: "OR('ForensicLabMSP.peer')"
    AnchorPeers:
      - Host: peer0.forensiclab.evidentia.network
        Port: 9051

  - &JudiciaryOrg
    Name: JudiciaryOrg
    ID: JudiciaryMSP
    MSPDir: crypto-config/peerOrganizations/judiciary.evidentia.network/msp
    Policies:
      Readers:
        Type: Signature
        Rule: "OR('JudiciaryMSP.admin', 'JudiciaryMSP.peer', 'JudiciaryMSP.client')"
      Writers:
        Type: Signature
        Rule: "OR('JudiciaryMSP.admin', 'JudiciaryMSP.client')"
      Admins:
        Type: Signature
        Rule: "OR('JudiciaryMSP.admin')"
      Endorsement:
        Type: Signature
        Rule: "OR('JudiciaryMSP.peer')"
    AnchorPeers:
      - Host: peer0.judiciary.evidentia.network
        Port: 11051

Capabilities:
  Channel: &ChannelCapabilities
    V2_0: true
  Orderer: &OrdererCapabilities
    V2_0: true
  Application: &ApplicationCapabilities
    V2_5: true

Application: &ApplicationDefaults
  Organizations:
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "MAJORITY Admins"
    LifecycleEndorsement:
      Type: ImplicitMeta
      Rule: "MAJORITY Endorsement"
    Endorsement:
      Type: ImplicitMeta
      Rule: "MAJORITY Endorsement"
  Capabilities:
    <<: *ApplicationCapabilities

Orderer: &OrdererDefaults
  OrdererType: etcdraft
  Addresses:
    - orderer.evidentia.network:7050
  EtcdRaft:
    Consenters:
      - Host: orderer.evidentia.network
        Port: 7050
        ClientTLSCert: crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/tls/server.crt
        ServerTLSCert: crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/tls/server.crt
  BatchTimeout: 2s
  BatchSize:
    MaxMessageCount: 10
    AbsoluteMaxBytes: 99 MB
    PreferredMaxBytes: 512 KB
  Organizations:
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "MAJORITY Admins"
    BlockValidation:
      Type: ImplicitMeta
      Rule: "ANY Writers"

Channel: &ChannelDefaults
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "MAJORITY Admins"
  Capabilities:
    <<: *ChannelCapabilities

Profiles:
  EvidentiaCoCGenesis:
    <<: *ChannelDefaults
    Orderer:
      <<: *OrdererDefaults
      Organizations:
        - *OrdererOrg
      Capabilities: *OrdererCapabilities
    Application:
      <<: *ApplicationDefaults
      Organizations:
        - *LawEnforcementOrg
        - *ForensicLabOrg
        - *JudiciaryOrg
      Capabilities: *ApplicationCapabilities
```

**IMPORTANT**: Update domain names and organization names to match your project. The profile name (`EvidentiaCoCGenesis`) should match your project name.

### Step 3.4: Create Docker Compose Files

**File**: `fabric-network/docker/docker-compose-couch.yaml`

```yaml
networks:
  evidentia:
    name: evidentia_network

services:
  couchdb.lawenforcement:
    container_name: couchdb.lawenforcement
    image: couchdb:3.3
    labels:
      service: hyperledger-fabric
    environment:
      - COUCHDB_USER=admin
      - COUCHDB_PASSWORD=adminpw
    ports:
      - "5984:5984"
    networks:
      - evidentia

  couchdb.forensiclab:
    container_name: couchdb.forensiclab
    image: couchdb:3.3
    labels:
      service: hyperledger-fabric
    environment:
      - COUCHDB_USER=admin
      - COUCHDB_PASSWORD=adminpw
    ports:
      - "6984:5984"
    networks:
      - evidentia

  couchdb.judiciary:
    container_name: couchdb.judiciary
    image: couchdb:3.3
    labels:
      service: hyperledger-fabric
    environment:
      - COUCHDB_USER=admin
      - COUCHDB_PASSWORD=adminpw
    ports:
      - "7984:5984"
    networks:
      - evidentia
```

**File**: `fabric-network/docker/docker-compose-fabric.yaml`

**CRITICAL CONFIGURATION POINTS**:
- Use `hyperledger/fabric-peer:2.5.10` and `hyperledger/fabric-orderer:2.5.10` images
- Set `CORE_VM_ENDPOINT=tcp://host.docker.internal:2375` for Windows Docker Desktop
- Set `CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=evidentia_network`
- Each peer connects to its own CouchDB instance
- Ports: Orderer (7050), LawEnforcement (7051), ForensicLab (9051), Judiciary (11051)
- TLS enabled on all components
- Mount crypto-config directories as volumes

**Key Environment Variables for Peers:**
```yaml
- CORE_LEDGER_STATE_STATEDATABASE=CouchDB
- CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdb.lawenforcement:5984
- CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=admin
- CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=adminpw
- CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=evidentia_network
- CORE_VM_ENDPOINT=tcp://host.docker.internal:2375
- DOCKER_API_VERSION=1.44
```

**Full docker-compose-fabric.yaml structure:**
- Orderer service (port 7050, 7053)
- 3 Peer services (one per organization)
- CLI service (optional, for manual operations)
- All services on `evidentia_network` Docker network
- Volumes mounted from `../crypto-config` and `../channel-artifacts`

### Step 3.5: Create Collections Config (if using private data)

**File**: `fabric-network/collections_config.json`

```json
[
  {
    "name": "sensitiveEvidenceMetadata",
    "policy": "OR('LawEnforcementMSP.member', 'ForensicLabMSP.member')",
    "requiredPeerCount": 1,
    "maxPeerCount": 3,
    "blockToLive": 0,
    "memberOnlyRead": true,
    "memberOnlyWrite": true,
    "endorsementPolicy": {
      "signaturePolicy": "OR('LawEnforcementMSP.peer', 'ForensicLabMSP.peer')"
    }
  }
]
```

---

## PART 4: POWERSHELL SCRIPTS FOR AUTOMATION

### Step 4.1: Generate-Crypto.ps1 Script

**File**: `fabric-network/scripts/Generate-Crypto.ps1`

**Purpose**: Generates all certificates and genesis block.

**Key Steps:**
1. Check `cryptogen` and `configtxgen` are in PATH
2. Remove existing `crypto-config` and `channel-artifacts` directories
3. Set `$env:FABRIC_CFG_PATH` to network directory
4. Run `cryptogen generate --config=crypto-config.yaml --output=crypto-config`
5. Run `configtxgen -profile EvidentiaCoCGenesis -outputBlock ./channel-artifacts/evidencechannel.block -channelID evidence-channel`
6. Verify generated files exist

**Critical**: The profile name in configtxgen command (`EvidentiaCoCGenesis`) must match the profile name in `configtx.yaml`.

### Step 4.2: Start-Network.ps1 Script

**File**: `fabric-network/scripts/Start-Network.ps1`

**Purpose**: Starts all Docker containers in correct order.

**Key Steps:**
1. Check Docker is running
2. Check crypto-config exists (run Generate-Crypto.ps1 first)
3. Create Docker network `evidentia_network` if not exists
4. Start CouchDB containers: `docker compose -f docker-compose-couch.yaml up -d`
5. Wait 10 seconds for CouchDB to initialize
6. Start Fabric containers: `docker compose -f docker-compose-fabric.yaml up -d`
7. Wait 15 seconds for Fabric to stabilize
8. Start IPFS (optional): `docker compose -f docker-compose-ipfs.yaml up -d`
9. Verify all containers are running

**Critical**: Start CouchDB BEFORE Fabric peers. Peers depend on CouchDB.

### Step 4.3: Create-Channel.ps1 Script

**File**: `fabric-network/scripts/Create-Channel.ps1`

**Purpose**: Creates channel and joins all peers.

**Key Steps:**
1. Set `$env:FABRIC_CFG_PATH` to `peercfg` directory
2. Use `osnadmin channel join` to create channel with genesis block
3. For each organization:
   - Set peer environment variables (`CORE_PEER_LOCALMSPID`, `CORE_PEER_TLS_ROOTCERT_FILE`, `CORE_PEER_MSPCONFIGPATH`, `CORE_PEER_ADDRESS`)
   - Run `peer channel join -b ./channel-artifacts/evidencechannel.block`
   - Wait 2-3 seconds between joins
4. Verify channel creation with `osnadmin channel list`

**Critical**: Use forward slashes (`/`) for file paths in environment variables on Windows. PowerShell handles this, but peer CLI expects Unix-style paths.

### Step 4.4: Deploy-Chaincode.ps1 Script

**File**: `fabric-network/scripts/Deploy-Chaincode.ps1`

**Purpose**: Packages, installs, approves, and commits chaincode.

**Key Steps:**
1. Check Go is installed
2. Check chaincode directory exists
3. Vendor Go modules: `go mod vendor` in chaincode directory
4. Package chaincode: `peer lifecycle chaincode package <name>.tar.gz --path <path> --lang golang --label <label>`
5. Install on all peers: `peer lifecycle chaincode install <package>.tar.gz`
6. Get package ID: `peer lifecycle chaincode queryinstalled`
7. Approve for each org: `peer lifecycle chaincode approveformyorg` (with `--collections-config` if using private data)
8. Commit: `peer lifecycle chaincode commit` (with all peer addresses and TLS certs)

**Critical Configuration:**
- Use forward slashes for paths (`/` instead of `\`)
- Set `$env:FABRIC_CFG_PATH` to `peercfg` directory
- Include `--collections-config` flag if using private data collections
- All organizations must approve before commit
- Commit requires TLS certs from all peers

---

## PART 5: EXECUTION SEQUENCE

### Complete Setup Workflow

```powershell
# 1. Navigate to project
Set-Location "C:\Projects\YourProjectName\fabric-network"

# 2. Generate crypto materials
.\scripts\Generate-Crypto.ps1

# 3. Start network
.\scripts\Start-Network.ps1

# 4. Wait 30 seconds for network to stabilize

# 5. Create channel and join peers
.\scripts\Create-Channel.ps1

# 6. Deploy chaincode
.\scripts\Deploy-Chaincode.ps1
```

### Verification Commands

```powershell
# Check containers are running
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check channel exists
osnadmin channel list -o localhost:7053 --ca-file <orderer-ca> --client-cert <cert> --client-key <key>

# Check chaincode is committed
peer lifecycle chaincode querycommitted --channelID evidence-channel --name evidence-coc

# Check peer logs
docker logs peer0.lawenforcement.evidentia.network --tail 50
```

---

## PART 6: CRITICAL WINDOWS-SPECIFIC CONFIGURATIONS

### Docker Desktop Settings

**MUST CONFIGURE:**
1. **WSL Integration**: Enable integration with your WSL distro
2. **Resources**: Minimum 8 GB RAM, 4 CPUs
3. **General**: Use WSL 2 based engine (NOT Hyper-V)

### Path Handling in Scripts

**CRITICAL**: On Windows, use forward slashes (`/`) for paths in environment variables passed to Fabric CLI tools:

```powershell
# WRONG (backslashes)
$env:CORE_PEER_MSPCONFIGPATH = "C:\Projects\...\msp"

# CORRECT (forward slashes)
$env:CORE_PEER_MSPCONFIGPATH = "C:/Projects/.../msp"
```

Or use PowerShell's `.Replace('\', '/')` method.

### Docker Network Configuration

**CRITICAL**: All containers must be on the same Docker network (`evidentia_network`). Peers need to resolve each other's hostnames.

**In docker-compose files:**
```yaml
networks:
  evidentia:
    name: evidentia_network
```

**For peer-to-peer communication:**
- Use container names as hostnames (e.g., `peer0.lawenforcement.evidentia.network`)
- Ensure all services are on the same network

### TLS Configuration

**ALL components use TLS:**
- Orderer: TLS enabled on port 7050
- Peers: TLS enabled on all ports
- Channel creation: Requires TLS certs
- Chaincode deployment: Requires TLS certs

**Certificate paths:**
- Orderer CA: `crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/msp/tlscacerts/`
- Peer TLS certs: `crypto-config/peerOrganizations/<org>/peers/peer0.<org>/tls/`

---

## PART 7: PORT MAPPING REFERENCE

| Service | Container Port | Host Port | Purpose |
|---------|---------------|-----------|---------|
| Orderer | 7050 | 7050 | Ordering service |
| Orderer Admin | 7053 | 7053 | Channel management API |
| LawEnforcement Peer | 7051 | 7051 | Peer service |
| ForensicLab Peer | 9051 | 9051 | Peer service |
| Judiciary Peer | 11051 | 11051 | Peer service |
| CouchDB (LE) | 5984 | 5984 | State database |
| CouchDB (FL) | 5984 | 6984 | State database |
| CouchDB (JD) | 5984 | 7984 | State database |
| IPFS API | 5001 | 5001 | IPFS API |
| IPFS Gateway | 8080 | 8080 | IPFS Gateway |

**IMPORTANT**: Ensure these ports are not in use by other applications.

---

## PART 8: TROUBLESHOOTING GUIDE

### Issue: Docker commands fail

**Solution:**
```powershell
# Check Docker is running
docker info

# Restart Docker Desktop if needed
# Check system tray for Docker icon
```

### Issue: Port already in use

**Solution:**
```powershell
# Find process using port
netstat -ano | findstr :7051

# Kill process (replace <PID> with actual PID)
taskkill /PID <PID> /F
```

### Issue: Crypto materials generation fails

**Solution:**
- Verify `cryptogen` and `configtxgen` are in PATH
- Check `crypto-config.yaml` syntax is valid YAML
- Ensure `FABRIC_CFG_PATH` is set correctly
- Verify all required directories exist

### Issue: Peers can't join channel

**Solution:**
- Wait 30+ seconds after starting network
- Check orderer logs: `docker logs orderer.evidentia.network`
- Verify genesis block exists: `Test-Path channel-artifacts/evidencechannel.block`
- Check peer environment variables are set correctly
- Verify TLS certificates exist and paths are correct

### Issue: Chaincode deployment fails

**Solution:**
- Verify Go is installed: `go version`
- Check chaincode directory has `go.mod` file
- Run `go mod vendor` manually in chaincode directory
- Verify all peers are running: `docker ps --filter "name=peer0"`
- Check package ID extraction logic (regex pattern)
- Verify collections_config.json exists if using private data
- Check peer logs for detailed errors

### Issue: Chaincode can't connect to peer

**Solution:**
- Verify `CORE_VM_ENDPOINT=tcp://host.docker.internal:2375` is set
- Check Docker Desktop exposes TCP endpoint (Settings → General → Expose daemon on tcp://localhost:2375)
- Verify `CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=evidentia_network`
- Ensure chaincode container is on same network as peers

### Issue: Reset Everything

**Complete Reset:**
```powershell
# Stop all containers
docker stop $(docker ps -q)
docker rm $(docker ps -aq)

# Remove volumes and networks
docker volume prune -f
docker network prune -f

# Remove crypto materials
Remove-Item -Recurse -Force crypto-config -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force channel-artifacts -ErrorAction SilentlyContinue

# Start fresh
.\scripts\Generate-Crypto.ps1
.\scripts\Start-Network.ps1
# Wait 30 seconds
.\scripts\Create-Channel.ps1
.\scripts\Deploy-Chaincode.ps1
```

---

## PART 9: ADAPTATION FOR YOUR PROJECT

### What to Change:

1. **Domain Names**: Replace `evidentia.network` with your domain
2. **Organization Names**: Replace `LawEnforcement`, `ForensicLab`, `Judiciary` with your orgs
3. **MSP IDs**: Update MSP IDs to match your organizations
4. **Channel Name**: Replace `evidence-channel` with your channel name
5. **Chaincode Name**: Replace `evidence-coc` with your chaincode name
6. **Profile Name**: Replace `EvidentiaCoCGenesis` with your profile name
7. **Ports**: Adjust ports if conflicts exist (keep peer ports unique)
8. **Network Name**: Replace `evidentia_network` with your network name

### What to Keep:

- WSL2 setup process
- Docker Desktop configuration
- Fabric binaries installation method
- Environment variable setup
- Script structure and logic
- Docker Compose file structure
- TLS configuration approach
- CouchDB setup (one per organization)

---

## PART 10: VERIFICATION CHECKLIST

Before considering setup complete, verify:

- [ ] WSL2 is installed and set as default version
- [ ] Docker Desktop is running and using WSL2 backend
- [ ] All Fabric binaries are in PATH (`peer version` works)
- [ ] `FABRIC_CFG_PATH` environment variable is set
- [ ] All Docker images are pulled
- [ ] Crypto materials generated successfully (`crypto-config/` exists)
- [ ] Genesis block generated (`channel-artifacts/evidencechannel.block` exists)
- [ ] All Docker containers are running (`docker ps` shows 8+ containers)
- [ ] Channel created successfully (`osnadmin channel list` shows channel)
- [ ] All peers joined channel (check peer logs)
- [ ] Chaincode packaged successfully (`<name>.tar.gz` exists)
- [ ] Chaincode installed on all peers
- [ ] Chaincode approved by all organizations
- [ ] Chaincode committed to channel (`peer lifecycle chaincode querycommitted` works)
- [ ] CouchDB instances are accessible (http://localhost:5984/_utils)
- [ ] IPFS is running (http://localhost:5001/api/v0/version)

---

## FINAL NOTES

**Estimated Setup Time**: 2-3 hours (first time)

**Key Success Factors**:
1. Follow steps in exact order
2. Wait for services to initialize (don't rush)
3. Verify each step before proceeding
4. Check logs if something fails
5. Use forward slashes for paths in environment variables
6. Ensure Docker Desktop is fully started before running scripts

**Common Mistakes to Avoid**:
- Skipping WSL2 setup
- Not setting environment variables correctly
- Using backslashes in paths for Fabric CLI
- Starting Fabric containers before CouchDB
- Not waiting for services to initialize
- Wrong profile name in configtxgen command
- Missing TLS certificates in chaincode deployment

**Next Steps After Setup**:
- Develop your chaincode in Go
- Create backend application to interact with Fabric
- Test chaincode functions
- Monitor network with CouchDB Fauxton UI
- Set up frontend application (if needed)

---

**This prompt contains everything needed to replicate the Hyperledger Fabric setup. Follow it step-by-step, and you will have a working multi-organization Fabric network on Windows 11.**


