# Evidentia: Blockchain-Based Digital Evidence Chain-of-Custody System

[![Hyperledger Fabric](https://img.shields.io/badge/Hyperledger%20Fabric-2.5-blue)](https://hyperledger-fabric.readthedocs.io/)
[![Node.js](https://img.shields.io/badge/Node.js-18+-green)](https://nodejs.org/)
[![React](https://img.shields.io/badge/React-18-61dafb)](https://reactjs.org/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

Evidentia is a production-ready implementation of a blockchain-based chain-of-custody framework for digital forensics investigations. Built on Hyperledger Fabric with IPFS storage integration, it provides tamper-proof, auditable tracking of digital evidence throughout its entire lifecycle.

## Overview

Based on the research paper ["Blockchain-Based Chain-of-Custody Models for Tamper-Proof Evidence Preservation in Digital Forensics Investigations"](https://www.doi.org/10.56726/IRJMETS80086), this system addresses critical challenges in digital evidence management:

- **Immutability**: All custody events are permanently recorded on a permissioned blockchain
- **Transparency**: Complete audit trails with cryptographic verification
- **Compliance**: Role-based access control aligned with legal admissibility requirements
- **Integration**: API gateway for forensic tool integration (Autopsy, EnCase, etc.)

## Key Features

### Blockchain Layer (Hyperledger Fabric)
- Multi-organization network (Law Enforcement, Forensic Lab, Judiciary)
- Smart contracts (chaincode) for evidence lifecycle management
- Private data collections for sensitive information
- Event-driven architecture for real-time updates

### Evidence Management
- Encrypted evidence storage on IPFS (AES-256-GCM)
- SHA-256 hash verification for integrity
- Complete custody chain tracking
- Automated status transitions

### Role-Based Access Control
- Evidence Collector: Register and transfer evidence
- Forensic Analyst: Analyze and document findings
- Supervisor: Verify and submit for review
- Legal Counsel/Judge: Admissibility decisions
- Auditor: Read-only access to audit trails

### Integration Gateway
- RESTful API for external tool integration
- JWT authentication with Fabric identity binding
- Webhook-style API for forensic tools
- Batch operation support

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Frontend (React)                           │
│                    Evidence Management Dashboard                     │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │
┌─────────────────────────────────▼───────────────────────────────────┐
│                    Integration Gateway (Node.js)                     │
│              REST API • Fabric SDK • IPFS Client • Auth              │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │
          ┌───────────────────────┼───────────────────────┐
          │                       │                       │
          ▼                       ▼                       ▼
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│  Law Enforce.   │   │  Forensic Lab   │   │   Judiciary     │
│     Peer        │   │      Peer       │   │     Peer        │
├─────────────────┤   ├─────────────────┤   ├─────────────────┤
│    CouchDB      │   │    CouchDB      │   │    CouchDB      │
└─────────────────┘   └─────────────────┘   └─────────────────┘
          │                       │                       │
          └───────────────────────┼───────────────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │     Orderer Service       │
                    │     (Raft Consensus)      │
                    └───────────────────────────┘

                    ┌───────────────────────────┐
                    │     IPFS Storage          │
                    │  (Encrypted Evidence)     │
                    └───────────────────────────┘
```

## Quick Start

### Prerequisites
- Docker Desktop 24.0+ (with WSL2 backend on Windows)
- Docker Compose v2.0+
- Go 1.21+
- Node.js 18+
- Hyperledger Fabric 2.5 binaries

### Installation

#### Windows 11 (PowerShell)

```powershell
# Clone the repository
git clone https://github.com/your-org/evidentia.git
cd evidentia

# Check prerequisites
.\scripts\Check-Prerequisites.ps1

# Generate crypto materials and start network
cd fabric-network
.\scripts\Generate-Crypto.ps1
.\scripts\Start-Network.ps1
.\scripts\Create-Channel.ps1
.\scripts\Deploy-Chaincode.ps1

# Start backend (new PowerShell window)
cd ..\backend
npm install
Copy-Item env.example .env
npm run dev

# Start frontend (new PowerShell window)
cd ..\frontend
npm install
npm start
```

**Quick Start (Windows):**
```powershell
# Or use the batch file menu
.\scripts\quick-start.bat
```

#### Linux / macOS (Bash)

```bash
# Clone the repository
git clone https://github.com/your-org/evidentia.git
cd evidentia

# Install Fabric (if not already installed)
curl -sSLO https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh
chmod +x install-fabric.sh
./install-fabric.sh --fabric-version 2.5.4 binary docker

# Generate crypto materials and start network
cd fabric-network
./scripts/generate.sh
./scripts/network.sh up
./scripts/channel.sh
./scripts/deploy-chaincode.sh

# Start backend
cd ../backend
npm install
cp env.example .env
npm run dev

# Start frontend (new terminal)
cd ../frontend
npm install
npm start
```

### Run Demo

**Windows:**
```powershell
.\scripts\Run-Demo.ps1
```

**Linux/macOS:**
```bash
./scripts/demo.sh
```

### Access the Application

- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:3001
- **IPFS Web UI**: http://localhost:5001/webui

**Default Login:** `admin` / `admin123`

See [SETUP.md](SETUP.md) for detailed installation instructions (Windows 11 focused).

## Project Structure

```
evidentia/
├── fabric-network/          # Hyperledger Fabric network configuration
│   ├── configtx.yaml        # Channel configuration
│   ├── crypto-config.yaml   # Certificate configuration
│   ├── docker/              # Docker compose files
│   └── scripts/             # Network management scripts
├── chaincode/evidence-coc/  # Go smart contracts
│   ├── chaincode.go         # Main contract logic
│   ├── models.go            # Data structures
│   └── access_control.go    # RBAC implementation
├── backend/                 # Node.js Integration Gateway
│   └── src/
│       ├── fabric/          # Fabric SDK integration
│       ├── services/        # IPFS, encryption services
│       ├── routes/          # REST API endpoints
│       └── middleware/      # Auth, RBAC middleware
├── frontend/                # React dashboard
│   └── src/
│       ├── pages/           # Dashboard, Evidence, Audit pages
│       ├── components/      # Reusable UI components
│       └── services/        # API client
└── forensic-simulator/      # Tool integration demo
```

## API Reference

### Authentication
```http
POST /api/auth/login
Content-Type: application/json

{"username": "collector@lawenforcement", "password": "password123"}
```

### Evidence Operations
```http
# Register evidence
POST /api/evidence
Authorization: Bearer <token>
Content-Type: multipart/form-data

# Get evidence
GET /api/evidence/:id

# Transfer custody
POST /api/evidence/:id/transfer

# Record analysis
POST /api/evidence/:id/analysis

# Submit for review
POST /api/evidence/:id/review
```

### Audit
```http
# Generate audit report
GET /api/audit/report/:evidenceId

# Get custody chain
GET /api/audit/custody-chain/:evidenceId

# Export report
GET /api/audit/export/:evidenceId?format=json
```

### Forensic Tool Integration
```http
# API Key authentication
X-API-Key: your-api-key

# Log tool action
POST /api/forensic/action
{
  "evidenceId": "EVD-123",
  "actionType": "ANALYSIS_COMPLETE",
  "details": {...}
}
```

## Evidence Lifecycle

```
REGISTERED → IN_CUSTODY → IN_ANALYSIS → ANALYZED → UNDER_REVIEW → ADMITTED/REJECTED → ARCHIVED
```

Each transition is recorded as an immutable event on the blockchain with:
- Timestamp
- Performing user and organization
- Transaction ID
- Reason/details

## Security Features

- **Encryption**: AES-256-GCM for evidence files before IPFS storage
- **Integrity**: SHA-256 hashing with blockchain verification
- **Authentication**: JWT tokens bound to Fabric X.509 identities
- **Authorization**: Multi-layer RBAC (API + chaincode level)
- **Audit**: Complete, tamper-proof audit trails
- **Privacy**: Private data collections for sensitive metadata

## Design Decisions

Where the research paper was underspecified, the following decisions were made:

| Gap | Decision | Rationale |
|-----|----------|-----------|
| Permission matrix | Least-privilege RBAC | Forensic best practices |
| Evidence encryption | AES-256-GCM per-evidence keys | Industry standard, per-evidence isolation |
| Status workflow | 9-state lifecycle | Covers complete forensic/legal process |
| API design | RESTful with JWT | Standard, easy integration |
| Private data scope | Sensitive metadata only | Balance transparency/privacy |

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## References

- [Original Research Paper](https://www.doi.org/10.56726/IRJMETS80086)
- [Hyperledger Fabric Documentation](https://hyperledger-fabric.readthedocs.io/)
- [IPFS Documentation](https://docs.ipfs.tech/)

## Acknowledgments

Based on research by Elvis Nnaemeka Chukwuani and Chukwujekwu Damian Ikemefuna, published in the International Research Journal of Modernization in Engineering Technology and Science.

