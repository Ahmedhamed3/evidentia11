# Evidentia Quick Start Guide

Quick reference for starting the system after a reboot.

## Prerequisites Check

1. **Start Docker Desktop** - Make sure it's fully running (whale icon in system tray)

## Startup Sequence

### Step 1: Start Fabric Network & IPFS

```powershell
cd C:\Projects\Evidentia\fabric-network
.\scripts\Start-Network.ps1
```

This starts:
- CouchDB containers (state databases)
- Fabric peers (3 organizations)
- Orderer
- IPFS node

**Wait ~30 seconds** for all containers to be ready.

### Step 2: Verify Network is Running

```powershell
docker ps --format "table {{.Names}}\t{{.Status}}"
```

You should see:
- `orderer.evidentia.network`
- `peer0.lawenforcement.evidentia.network`
- `peer0.forensiclab.evidentia.network`
- `peer0.judiciary.evidentia.network`
- `couchdb0.lawenforcement.evidentia.network`
- `couchdb0.forensiclab.evidentia.network`
- `couchdb0.judiciary.evidentia.network`
- `ipfs.evidentia.network`

### Step 3: Check Channel & Chaincode

If you see errors about channel or chaincode, run:

```powershell
# Create channel (if needed)
.\scripts\Create-Channel.ps1

# Deploy chaincode (if needed - use CCaaS method)
.\scripts\Deploy-Chaincode-CCaaS.ps1
```

**Note:** If chaincode container exists but needs restart:
```powershell
cd C:\Projects\Evidentia\chaincode\evidence-coc
docker stop evidentia-chaincode
docker rm evidentia-chaincode
$PackageId = "evidence-coc_1.0:54a1a0d774ec0f385f60f815bcc04a86b4e7f5ba6eb9c552a3144850c205a6c1"
docker run -d --name evidentia-chaincode --network evidentia_network -e CHAINCODE_ID=$PackageId -e CHAINCODE_SERVER_ADDRESS=0.0.0.0:9999 -p 9999:9999 evidentia-chaincode:1.0
```

### Step 4: Start Backend

Open a **new PowerShell window**:

```powershell
cd C:\Projects\Evidentia\backend
npm run dev
```

Wait for: `Server running on port 3001`

### Step 5: Start Frontend

Open **another new PowerShell window**:

```powershell
cd C:\Projects\Evidentia\frontend
npm start
```

Wait for: `webpack compiled successfully` and browser opens to `http://localhost:3000`

## Quick Status Check

```powershell
# Check all services
docker ps --format "table {{.Names}}\t{{.Status}}"

# Test IPFS
Invoke-RestMethod -Uri "http://localhost:5001/api/v0/version" -Method Post

# Test Backend (should return JSON)
Invoke-RestMethod -Uri "http://localhost:3001/api/health" -Method Get
```

## Access Points

- **Frontend UI:** http://localhost:3000
- **Backend API:** http://localhost:3001
- **IPFS Web UI:** http://localhost:5001/webui
- **CouchDB (LawEnforcement):** http://localhost:5984/_utils
- **CouchDB (ForensicLab):** http://localhost:6984/_utils
- **CouchDB (Judiciary):** http://localhost:7984/_utils

## Default Login Credentials

- **Username:** `admin`
- **Password:** `admin123`

Or use any of the demo users:
- `collector@lawenforcement` / `password123` (Officer Ahmed)
- `supervisor@lawenforcement` / `password123` (Sergeant Mohamed)
- `analyst@forensiclab` / `password123` (Dr. Fatima)
- `supervisor@forensiclab` / `password123` (Dr. Khaled)
- `counsel@judiciary` / `password123` (Attorney Ali)
- `judge@judiciary` / `password123` (Judge Sara)
- `auditor@judiciary` / `password123` (Auditor Omar)

## Troubleshooting

### Network not starting?
```powershell
# Check Docker is running
docker info

# Check if ports are in use
netstat -ano | findstr "7050 7051 9051 11051 5001"
```

### Chaincode errors?
```powershell
# Check chaincode container logs
docker logs evidentia-chaincode

# Check peer logs
docker logs peer0.forensiclab.evidentia.network --tail 50
```

### Backend connection errors?
- Make sure Fabric network is fully started (wait 30+ seconds)
- Check backend logs for specific error messages
- Verify `.env` file exists in `backend/` directory

## Stop Everything

```powershell
# Stop frontend (Ctrl+C in its window)
# Stop backend (Ctrl+C in its window)

# Stop network
cd C:\Projects\Evidentia\fabric-network\docker
docker compose -f docker-compose-fabric.yaml down
docker compose -f docker-compose-couch.yaml down
docker compose -f docker-compose-ipfs.yaml down

# Stop chaincode
docker stop evidentia-chaincode
docker rm evidentia-chaincode
```

