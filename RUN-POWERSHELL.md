# How to Run Evidentia Using PowerShell

## Prerequisites
1. **Docker Desktop** must be running (check system tray for whale icon)
2. All dependencies installed (Node.js, npm, etc.)

## Quick Start (Automated)

### Step 1: Start Everything at Once

Open PowerShell in the project root directory and run:

```powershell
.\scripts\Start-All.ps1
```

This script will:
- Check if Docker is running
- Start the Fabric network (if not already running)
- Open a new PowerShell window for the backend
- Open a new PowerShell window for the frontend

**Wait 30-60 seconds** for all services to start.

### Step 2: Access the Application

- **Frontend UI**: http://localhost:3000
- **Backend API**: http://localhost:3001
- **IPFS Web UI**: http://localhost:5001/webui

**Default Login**: `admin` / `admin123`

---

## Manual Start (Step-by-Step)

If you prefer to start services manually or the automated script doesn't work:

### Step 1: Start Fabric Network

```powershell
# Navigate to fabric-network directory
cd fabric-network

# Generate crypto materials (first time only)
.\scripts\Generate-Crypto.ps1

# Start the network
.\scripts\Start-Network.ps1

# Wait ~30 seconds for containers to start, then create channel (first time only)
.\scripts\Create-Channel.ps1

# Deploy chaincode (first time only)
.\scripts\Deploy-Chaincode-CCaaS.ps1
```

### Step 2: Verify Network is Running

```powershell
docker ps --format "table {{.Names}}\t{{.Status}}"
```

You should see containers like:
- `orderer.evidentia.network`
- `peer0.lawenforcement.evidentia.network`
- `peer0.forensiclab.evidentia.network`
- `peer0.judiciary.evidentia.network`
- `ipfs.evidentia.network`

### Step 3: Start Backend

Open a **new PowerShell window**:

```powershell
cd backend

# Install dependencies (first time only)
npm install

# Create .env file if it doesn't exist (first time only)
if (-not (Test-Path .env)) {
    Copy-Item env.example .env
}

# Start backend server
npm run dev
```

Wait for: `Server running on port 3001`

### Step 4: Start Frontend

Open **another new PowerShell window**:

```powershell
cd frontend

# Install dependencies (first time only)
npm install

# Start frontend
npm start
```

Wait for browser to open at `http://localhost:3000`

---

## Verify Everything is Running

Run this in PowerShell to check all services:

```powershell
# Check Docker containers
docker ps --format "table {{.Names}}\t{{.Status}}"

# Test IPFS
Invoke-RestMethod -Uri "http://localhost:5001/api/v0/version" -Method Post

# Test Backend
Invoke-RestMethod -Uri "http://localhost:3001/api/health" -Method Get
```

---

## Stop Everything

### Stop Frontend & Backend
- Press `Ctrl+C` in each PowerShell window

### Stop Fabric Network

```powershell
cd fabric-network
.\scripts\Stop-Network.ps1
```

Or use the stop script from root:

```powershell
.\scripts\Stop-All.ps1
```

---

## Troubleshooting

### Docker not running?
```powershell
# Check Docker status
docker info
```

### Ports already in use?
```powershell
# Check what's using the ports
netstat -ano | findstr "3000 3001 5001 7050 7051"
```

### Network containers not starting?
```powershell
# Check Docker logs
docker logs peer0.lawenforcement.evidentia.network --tail 50
```

### Backend connection errors?
- Make sure Fabric network is fully started (wait 30+ seconds)
- Check that `.env` file exists in `backend/` directory
- Verify backend logs for specific error messages

### Chaincode errors?
```powershell
# Check chaincode container
docker logs evidentia-chaincode --tail 50
```

---

## Demo Script

To run a complete demo of the evidence lifecycle:

```powershell
.\scripts\Run-Demo.ps1
```

This demonstrates:
1. Officer registers evidence
2. Transfer to forensic lab
3. Forensic analysis
4. Submit for judicial review
5. Judicial decision
6. Audit report generation

---

## Access Points

- **Frontend UI**: http://localhost:3000
- **Backend API**: http://localhost:3001
- **IPFS Web UI**: http://localhost:5001/webui
- **CouchDB (LawEnforcement)**: http://localhost:5984/_utils
- **CouchDB (ForensicLab)**: http://localhost:6984/_utils
- **CouchDB (Judiciary)**: http://localhost:7984/_utils

---

## Default Login Credentials

- **Admin**: `admin` / `admin123`
- **Collector**: `collector@lawenforcement` / `password123`
- **Supervisor**: `supervisor@lawenforcement` / `password123`
- **Analyst**: `analyst@forensiclab` / `password123`
- **Lab Supervisor**: `supervisor@forensiclab` / `password123`
- **Legal Counsel**: `counsel@judiciary` / `password123`
- **Judge**: `judge@judiciary` / `password123`
- **Auditor**: `auditor@judiciary` / `password123`

