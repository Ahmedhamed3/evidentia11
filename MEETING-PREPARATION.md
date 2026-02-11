

---

## 📋 Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Technology Fundamentals](#2-technology-fundamentals)
3. [System Architecture](#3-system-architecture)
4. [How It Works: End-to-End](#4-how-it-works-end-to-end)
5. [Key Features Deep Dive](#5-key-features-deep-dive)
6. [Security & Integrity](#6-security--integrity)
7. [Common Questions & Answers](#7-common-questions--answers)
8. [Technical Implementation Details](#8-technical-implementation-details)
9. [Project Strengths & Innovations](#9-project-strengths--innovations)

---

## 1. Executive Summary

### What is Evidentia?

**Evidentia** is a **blockchain-based digital evidence chain-of-custody management system** designed for law enforcement, forensic laboratories, and judicial systems. It ensures:

- **Immutable Audit Trail**: Every evidence action is permanently recorded on blockchain
- **Integrity Verification**: Cryptographic hashing ensures evidence hasn't been tampered with
- **Secure Storage**: Evidence files are encrypted and stored on IPFS (distributed storage)
- **Role-Based Access Control**: Different organizations and roles have specific permissions
- **Complete Transparency**: Full custody chain visible to authorized parties

### The Problem It Solves

Traditional evidence management has critical weaknesses:
- **Paper trails can be lost or altered**
- **Digital evidence can be tampered with**
- **Custody transfers lack transparency**
- **No real-time integrity verification**
- **Audit trails are centralized and vulnerable**

**Evidentia solves these by using blockchain for immutable records and IPFS for secure, distributed storage.**

---

## 2. Technology Fundamentals

### 2.1 What is Hyperledger Fabric?

**Hyperledger Fabric** is an **enterprise-grade, permissioned blockchain platform** (unlike public blockchains like Bitcoin/Ethereum).

#### Key Concepts:

**Blockchain Basics:**
- A **distributed ledger** that records transactions in blocks
- Each block is cryptographically linked to the previous one (chain)
- Once written, data cannot be altered (immutability)
- Multiple parties maintain copies (distributed consensus)

**Permissioned vs Permissionless:**
- **Permissionless** (Bitcoin, Ethereum): Anyone can join, read, write
- **Permissioned** (Fabric): Only authorized organizations can participate
- **Why permissioned?** Legal/forensic systems need privacy and control

#### Hyperledger Fabric Components:

**1. Organizations (Orgs)**
- Independent entities with their own identity
- In Evidentia: **LawEnforcement**, **ForensicLab**, **Judiciary**
- Each org has its own **MSP** (Membership Service Provider) - think of it as their "identity card"

**2. Peers**
- **What they are**: Nodes that maintain a copy of the ledger
- **What they do**: 
  - Store blockchain data (ledger)
  - Execute chaincode (smart contracts)
  - Validate transactions
- **In our system**: Each organization has at least one peer
  - `peer0.lawenforcement.evidentia.network`
  - `peer0.forensiclab.evidentia.network`
  - `peer0.judiciary.evidentia.network`

**3. Orderer**
- **What it is**: A special node that orders transactions into blocks
- **What it does**: 
  - Receives transactions from peers
  - Orders them chronologically
  - Packages them into blocks
  - Distributes blocks to all peers
- **Why needed**: Ensures all peers see transactions in the same order
- **In our system**: `orderer.evidentia.network` (using Raft consensus)

**4. Channel**
- **What it is**: A private "subnet" of the blockchain
- **What it does**: Isolates data - only channel members can see transactions
- **In our system**: Single channel `evidence-channel` shared by all 3 orgs

**5. Chaincode (Smart Contracts)**
- **What it is**: Business logic code that runs on the blockchain
- **What it does**: Defines what transactions are allowed and how they're processed
- **In our system**: Written in Go, handles evidence registration, transfers, analysis, etc.

**6. MSP (Membership Service Provider)**
- **What it is**: Manages identities and certificates for an organization
- **What it does**: 
  - Issues X.509 certificates to users
  - Defines who belongs to the organization
  - Validates identities in transactions
- **In our system**: Each org has its own MSP (LawEnforcementMSP, ForensicLabMSP, JudiciaryMSP)

### 2.2 How Hyperledger Fabric Transactions Work

**Step-by-Step Transaction Flow:**

1. **Client submits transaction** → Backend API calls Fabric Gateway
2. **Gateway sends to endorsing peers** → Peers execute chaincode
3. **Endorsing peers return results** → Signed responses with read/write sets
4. **Gateway collects endorsements** → Needs enough signatures (endorsement policy)
5. **Gateway sends to orderer** → Orderer orders transactions
6. **Orderer creates block** → Packages transactions chronologically
7. **Orderer distributes block** → Sends to all peers on channel
8. **Peers validate block** → Check endorsements, conflicts
9. **Peers commit to ledger** → Write to blockchain (immutable)

**Why This Matters:**
- **Endorsement**: Multiple peers must agree (prevents fraud)
- **Ordering**: Ensures consistent transaction order
- **Validation**: Prevents double-spending and conflicts
- **Immutability**: Once committed, cannot be changed

### 2.3 What is IPFS?

**IPFS (InterPlanetary File System)** is a **distributed file storage system**.

#### Key Concepts:

**Distributed Storage:**
- Files are stored across multiple nodes (not centralized)
- Each file gets a unique **CID** (Content Identifier) - like a hash
- Anyone with the CID can retrieve the file
- Files are **content-addressed** (by content, not location)

**Why IPFS for Evidence?**
- **Decentralization**: No single point of failure
- **Persistence**: Files remain available even if some nodes go down
- **Integrity**: CID is derived from file content (tampering changes CID)
- **Efficiency**: Content deduplication (same file = same CID)

**How It Works:**
1. File is split into chunks
2. Each chunk is hashed
3. Chunks are distributed to IPFS nodes
4. CID is generated from the file structure
5. CID is stored on blockchain (not the file itself)

**In Our System:**
- Evidence files are **encrypted** before upload to IPFS
- Only the **CID** (not the file) is stored on blockchain
- Original file hash (SHA-256) is also stored for integrity verification

### 2.4 Encryption: AES-256-GCM

**What is AES-256-GCM?**
- **AES-256**: Advanced Encryption Standard with 256-bit keys (very strong)
- **GCM**: Galois/Counter Mode - provides both encryption AND authentication
- **Why GCM?** Detects if encrypted data has been tampered with

**How We Use It:**
1. Each evidence file gets a unique encryption key (derived from master key + key ID)
2. File is encrypted with AES-256-GCM
3. Encrypted file + IV (initialization vector) + auth tag are packaged
4. Package is uploaded to IPFS
5. Only the **key ID** is stored on blockchain (not the key itself)

**Security Benefits:**
- Even if IPFS is compromised, files are encrypted
- Each evidence has its own key (isolation)
- Authentication tag prevents tampering

---

## 3. System Architecture

### 3.1 High-Level Architecture

```
┌─────────────────┐
│   Frontend      │  React Web UI (Port 3000)
│   (React)       │  - Evidence registration
└────────┬────────┘  - Custody transfer
         │           - Analysis recording
         │           - Audit reports
         ▼
┌─────────────────┐
│   Backend API   │  Node.js/Express (Port 3001)
│   (Gateway)     │  - REST API endpoints
└────────┬────────┘  - JWT authentication
         │           - Fabric Gateway client
         │           - IPFS client
         │           - Encryption service
         │
    ┌────┴────┬──────────────┐
    │         │              │
    ▼         ▼              ▼
┌────────┐ ┌────────┐   ┌──────────┐
│Fabric  │ │  IPFS  │   │Encryption│
│Network │ │  Node  │   │  Service │
└────────┘ └────────┘   └──────────┘
```

### 3.2 Three-Organization Network

**Organization 1: LawEnforcementMSP**
- **Role**: Initial evidence collection and registration
- **Users**: Officers (Collectors), Sergeants (Supervisors)
- **Permissions**: Register evidence, transfer custody, view audit

**Organization 2: ForensicLabMSP**
- **Role**: Evidence analysis and examination
- **Users**: Analysts, Lab Supervisors
- **Permissions**: Receive custody, record analysis, submit for review

**Organization 3: JudiciaryMSP**
- **Role**: Judicial review and decisions
- **Users**: Legal Counsel, Judges, Auditors
- **Permissions**: Review evidence, record decisions, generate reports

### 3.3 Technology Stack

**Frontend:**
- React + TypeScript
- Tailwind CSS (styling)
- React Router (navigation)
- Axios (API calls)

**Backend:**
- Node.js + TypeScript
- Express (web framework)
- Hyperledger Fabric Gateway SDK
- IPFS HTTP API client
- JWT authentication
- Multer (file uploads)

**Blockchain:**
- Hyperledger Fabric 2.5
- Go chaincode (smart contracts)
- CouchDB (state database)

**Storage:**
- IPFS (distributed file storage)
- Docker containers (network components)

---

## 4. How It Works: End-to-End

### 4.1 Evidence Registration Flow

**When an officer registers new evidence:**

1. **Frontend**: User uploads file via web interface
2. **Backend receives file**:
   - Computes **SHA-256 hash** of original file
   - Generates unique **encryption key ID**
   - Encrypts file with **AES-256-GCM**
3. **Upload to IPFS**:
   - Encrypted file is uploaded to IPFS
   - Receives **CID** (Content Identifier)
4. **Register on Blockchain**:
   - Backend calls Fabric Gateway
   - Gateway submits transaction to endorsing peers
   - Chaincode validates permissions
   - Creates evidence record with:
     - Evidence ID (EVD-XXXXXXXX)
     - Case ID
     - IPFS CID
     - SHA-256 hash
     - Encryption key ID
     - Metadata (name, type, size, etc.)
     - Current custodian (officer's identity)
     - Status: REGISTERED
   - Transaction is ordered and committed
5. **Response**: Frontend shows success, evidence appears in list

**Key Points:**
- File is **never stored on blockchain** (only CID and hash)
- Original hash is stored for **integrity verification**
- Registration event is **permanently recorded**

### 4.2 Custody Transfer Flow

**When evidence is transferred (e.g., Law Enforcement → Forensic Lab):**

1. **Frontend**: Officer selects evidence and target user
2. **Backend validates**:
   - Current custodian matches requester
   - Target organization can receive custody
   - User has TRANSFER_CUSTODY permission
3. **Blockchain transaction**:
   - Chaincode updates evidence record:
     - `currentCustodian` → new user ID
     - `currentOrg` → new organization
     - `status` → IN_CUSTODY or IN_ANALYSIS
   - Creates **custody event**:
     - Event type: TRANSFER
     - From entity/org
     - To entity/org
     - Timestamp
     - Transaction ID
     - Performed by
4. **Response**: Frontend updates, shows in custody timeline

**Key Points:**
- Transfer is **atomic** (all-or-nothing)
- Event is **immutable** (cannot be deleted)
- Full chain is **traceable**

### 4.3 Analysis Recording Flow

**When a forensic analyst records analysis:**

1. **Frontend**: Analyst fills analysis form (findings, tools used, artifacts)
2. **Backend validates**:
   - User is current custodian or has access
   - User has RECORD_ANALYSIS permission
   - Evidence status allows analysis
3. **Blockchain transaction**:
   - Creates **analysis record**:
     - Analysis ID
     - Evidence ID
     - Analyst ID
     - Tool used
     - Findings
     - Artifacts found
     - Timestamp
   - Updates evidence status to ANALYZED
   - Creates ANALYSIS_END event
4. **Response**: Analysis appears in evidence history

**Key Points:**
- Analysis is **permanently linked** to evidence
- Cannot be modified after recording
- Full audit trail of who analyzed what

### 4.4 Judicial Review Flow

**When evidence is submitted for judicial review:**

1. **Frontend**: Analyst/Supervisor submits for review
2. **Backend validates**:
   - User has SUBMIT_FOR_REVIEW permission
   - Evidence status is ANALYZED
3. **Blockchain transaction**:
   - Updates status to UNDER_REVIEW
   - Creates JUDICIAL_SUBMIT event
   - Transfers custody to Judiciary org (if needed)
4. **Legal Counsel reviews**:
   - Views evidence and analysis
   - Records decision (ADMITTED/REJECTED)
   - Provides reasoning
5. **Blockchain transaction**:
   - Updates status to ADMITTED or REJECTED
   - Creates JUDICIAL_DECISION event
   - Records decision reasoning

**Key Points:**
- Review process is **transparent** and **auditable**
- Decision is **immutable** once recorded
- Full reasoning is preserved

---

## 5. Key Features Deep Dive

### 5.1 Integrity Verification

**What is "Integrity Verified"?**

When you see "Integrity Verified: ✓" in the UI, it means the evidence file's hash matches the hash stored on the blockchain.

**How It Works:**

1. **During Registration**:
   - Original file hash (SHA-256) is computed
   - Hash is stored on blockchain in evidence record
   - `integrityVerified` flag is set to `true`

2. **During Verification** (manual or automatic):
   - System retrieves evidence from IPFS
   - Decrypts the file
   - Computes SHA-256 hash of decrypted file
   - Compares with stored hash from blockchain
   - If match: `integrityVerified = true`
   - If mismatch: `integrityVerified = false` (tampering detected!)

3. **In the Frontend**:
   - Shows green checkmark if verified
   - Shows warning if not verified or mismatch

**Why This Matters:**
- **Tampering Detection**: Any change to the file changes its hash
- **Chain of Custody**: Proves evidence hasn't been altered
- **Legal Admissibility**: Courts require proof of integrity

**Technical Implementation:**
```typescript
// Backend computes hash
const evidenceHash = computeHash(file.buffer); // SHA-256

// Stored on blockchain
evidence.evidenceHash = evidenceHash;

// Verification
const decryptedFile = await downloadEvidence(cid, keyId);
const computedHash = computeHash(decryptedFile);
const verified = computedHash === evidence.evidenceHash;
```

### 5.2 Role-Based Access Control (RBAC)

**What is RBAC?**

Different users have different permissions based on their role and organization.

**Our Role System:**

| Role | Organization | Key Permissions |
|------|-------------|----------------|
| **Collector** | LawEnforcement | Register evidence, Transfer custody |
| **Analyst** | ForensicLab | Receive custody, Record analysis, Submit for review |
| **Supervisor** | LawEnforcement/ForensicLab | All collector/analyst permissions + Verify, Generate reports |
| **Legal Counsel** | Judiciary | Review evidence, Record decisions |
| **Judge** | Judiciary | Record decisions, Generate reports |
| **Auditor** | Judiciary | View evidence, Generate audit reports (read-only) |

**How It Works:**

1. **User Authentication**:
   - User logs in with credentials
   - Backend validates and issues JWT token
   - Token contains user ID, role, organization (MSP ID)

2. **API Level** (Backend):
   - Middleware checks JWT token
   - Validates user has required permission
   - Example: `requirePermission('evidence:create')`

3. **Chaincode Level** (Blockchain):
   - Extracts user identity from transaction
   - Gets X.509 certificate (contains role, org)
   - Checks role permissions
   - Checks organization permissions
   - Rejects if not authorized

**Why Two Layers?**
- **API layer**: Fast rejection, better UX
- **Chaincode layer**: Final security, cannot be bypassed

**Example:**
```go
// Chaincode checks permission
identity, err := RequirePermission(ctx, PermRecordAnalysis)
if err != nil {
    return err // Access denied
}
// Proceed with analysis recording
```

### 5.3 Audit Trail & History

**What is an Audit Trail?**

A complete, chronological record of all actions performed on evidence.

**What Gets Recorded:**

Every action creates a **CustodyEvent**:
- Event ID (unique)
- Evidence ID
- Event Type (REGISTRATION, TRANSFER, ANALYSIS, etc.)
- From/To entities and organizations
- Timestamp (Unix epoch)
- Transaction ID (blockchain TXID)
- Performed by (user ID, role, org)
- Reason/details
- Verified status

**How to View:**

1. **Frontend**: Evidence Detail page → History tab
2. **API**: `GET /api/evidence/:id/history`
3. **Chaincode**: `GetEvidenceHistory(evidenceId)`

**Why It Matters:**
- **Legal Requirement**: Courts need complete chain of custody
- **Accountability**: Know exactly who did what and when
- **Transparency**: All parties can verify actions
- **Immutability**: Cannot be altered or deleted

**Example Event:**
```json
{
  "eventId": "EVT-EVD-123-1699123456",
  "evidenceId": "EVD-123",
  "eventType": "TRANSFER",
  "fromEntity": "collector-le-001",
  "fromOrg": "LawEnforcementMSP",
  "toEntity": "analyst-fl-001",
  "toOrg": "ForensicLabMSP",
  "timestamp": 1699123456,
  "txId": "abc123def456...",
  "performedBy": "collector-le-001",
  "performerRole": "COLLECTOR"
}
```

### 5.4 Transaction ID (TXID)

**What is TXID?**

Every blockchain transaction gets a unique **Transaction ID** (TXID). It's like a receipt number.

**Where You See It:**
- Evidence Detail page → Cryptographic Hashes section
- Audit reports
- Custody event history

**What It's Used For:**
- **Verification**: Can look up exact transaction on blockchain
- **Audit**: Prove when and how evidence was registered
- **Debugging**: Trace issues to specific transactions
- **Legal**: Court can verify transaction authenticity

**Example:**
```
TXID: 3a7f9b2c8d1e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0
```

### 5.5 IPFS CID (Content Identifier)

**What is CID?**

**CID** (Content Identifier) is a unique hash that identifies content on IPFS.

**Characteristics:**
- **Content-addressed**: Same content = same CID
- **Tamper-proof**: Changing content changes CID
- **Persistent**: CID always points to same content

**In Our System:**
- Evidence file is encrypted
- Encrypted file is uploaded to IPFS
- IPFS returns CID (e.g., `QmXyZ123...`)
- CID is stored on blockchain (not the file)

**Why Store CID, Not File?**
- **Blockchain size**: Files are too large for blockchain
- **Cost**: Storing files on-chain is expensive
- **Efficiency**: CID is small (46 characters), file could be GBs
- **Decentralization**: File stored on IPFS (distributed), CID on blockchain (immutable reference)

**How to Retrieve:**
```typescript
// Download from IPFS using CID
const decryptedFile = await downloadEvidence(cid, encryptionKeyId);
```

### 5.6 Encryption Key ID

**What is Encryption Key ID?**

A unique identifier for the encryption key used to encrypt evidence.

**How It Works:**
1. During registration, system generates `KEY-UUID`
2. Key is derived from master key + key ID (using HKDF)
3. Evidence is encrypted with this key
4. **Only the key ID** is stored on blockchain (not the key itself)
5. Key is stored securely in backend (in production, use HSM)

**Why Not Store Key on Blockchain?**
- **Security**: Keys should never be on public/accessible ledgers
- **Privacy**: Even permissioned blockchains can be audited
- **Best Practice**: Keys stored separately, only ID referenced

**In Production:**
- Keys stored in Hardware Security Module (HSM)
- Or key management service (AWS KMS, Azure Key Vault)
- Backend retrieves key using key ID when needed

---

## 6. Security & Integrity

### 6.1 Multi-Layer Security

**Layer 1: Network Security**
- TLS encryption for all communications
- Certificate-based authentication (X.509)
- Private network (Docker containers)

**Layer 2: Application Security**
- JWT authentication for API
- Role-based access control (RBAC)
- Input validation and sanitization

**Layer 3: Blockchain Security**
- Permissioned network (only authorized orgs)
- Endorsement policies (multiple peers must agree)
- Immutable ledger (cannot alter history)

**Layer 4: Data Security**
- Evidence files encrypted (AES-256-GCM)
- Encryption keys stored separately
- IPFS for distributed storage (no single point of failure)

**Layer 5: Integrity**
- SHA-256 hashing for tamper detection
- Hash stored on blockchain
- Verification on every access

### 6.2 How Integrity Verification Works

**Step-by-Step:**

1. **Registration**:
   ```
   Original File → SHA-256 Hash → Stored on Blockchain
   ```

2. **Storage**:
   ```
   Original File → Encrypt (AES-256-GCM) → Upload to IPFS → Get CID
   ```

3. **Verification** (when needed):
   ```
   Download from IPFS (using CID) → Decrypt → Compute SHA-256 Hash
   Compare with stored hash → Match = Verified ✓
   ```

4. **If Tampered**:
   ```
   Modified File → Different Hash → Mismatch → Integrity Failed ✗
   ```

**Why This Works:**
- **Cryptographic Hash**: SHA-256 is one-way (cannot reverse)
- **Avalanche Effect**: Tiny change → completely different hash
- **Immutability**: Hash on blockchain cannot be changed
- **Verification**: Anyone can verify by recomputing hash

### 6.3 Access Control Details

**Permission Matrix:**

| Permission | Collector | Analyst | Supervisor | Legal Counsel | Judge | Auditor |
|------------|-----------|---------|------------|---------------|-------|---------|
| Register Evidence | ✓ | | ✓ | | | |
| Transfer Custody | ✓ | ✓ | ✓ | | | |
| Record Analysis | | ✓ | ✓ | | | |
| Submit for Review | | ✓ | ✓ | | | |
| Record Decision | | | | ✓ | ✓ | |
| Generate Report | | | ✓ | ✓ | ✓ | ✓ |
| View Audit | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

**Organization-Level Permissions:**
- LawEnforcementMSP: Can register, transfer, view
- ForensicLabMSP: Can receive, analyze, transfer
- JudiciaryMSP: Can review, decide, audit

**Enforcement:**
- **API Middleware**: Fast rejection, user-friendly errors
- **Chaincode**: Final authority, cannot be bypassed
- **Both must pass**: Transaction only succeeds if both allow

---

## 7. Common Questions & Answers

### Q1: "Why use blockchain instead of a regular database?"

**Answer:**
- **Immutability**: Database records can be deleted/modified. Blockchain records are permanent.
- **Trust**: Multiple organizations don't need to trust a central authority. Blockchain provides distributed trust.
- **Audit Trail**: Complete, tamper-proof history of all actions.
- **Transparency**: All parties can verify transactions independently.
- **Legal Admissibility**: Courts accept blockchain records as evidence of chain of custody.

**Example Scenario:**
If a database is used and someone with admin access deletes a custody transfer record, there's no proof it happened. On blockchain, even if someone tries to alter data, all other peers reject it, and the original transaction remains visible.

### Q2: "Why not store files directly on the blockchain?"

**Answer:**
- **Size Limits**: Blockchains have block size limits (typically 1-10 MB). Evidence files can be GBs.
- **Cost**: Storing large files on-chain is extremely expensive (gas fees, storage costs).
- **Performance**: Large files slow down transaction processing.
- **Best Practice**: Store files off-chain (IPFS), store references on-chain (CID, hash).

**Our Approach:**
- File → Encrypt → IPFS → Get CID
- Store CID + hash on blockchain (small, efficient)
- Retrieve file from IPFS when needed

### Q3: "How do you ensure IPFS files aren't lost?"

**Answer:**
- **Pinning**: We pin evidence files on IPFS (prevents garbage collection)
- **Distributed**: Files are replicated across IPFS nodes
- **CID Verification**: CID is content-addressed (same content = same CID, even if stored on different nodes)
- **Production**: Use IPFS pinning services (Pinata, Infura) for guaranteed persistence

**Current Implementation:**
- Local IPFS node pins all evidence
- In production, use commercial pinning services for redundancy

### Q4: "What happens if someone hacks the backend server?"

**Answer:**
- **Encryption Keys**: Keys are derived from master key (stored in environment variable, not in code)
- **Blockchain Protection**: Even if backend is compromised, blockchain transactions require:
  - Valid X.509 certificates (from Fabric CA)
  - Proper endorsements (multiple peers must agree)
  - Correct permissions (chaincode enforces)
- **Read-Only Access**: Hacker can read data but cannot create fraudulent transactions without valid certificates
- **Audit Trail**: All actions are logged, so unauthorized access is detectable

**Best Practices We Follow:**
- Keys stored in environment variables (not hardcoded)
- JWT tokens expire
- Chaincode validates all transactions
- All actions are logged and auditable

### Q5: "How is this different from just using encryption and a database?"

**Answer:**
- **Single Point of Failure**: Database can be compromised, corrupted, or lost
- **Trust Requirement**: All parties must trust the database administrator
- **Audit Trail**: Database logs can be deleted or modified
- **Multi-Organization**: Each org would need access to same database (security risk)

**Blockchain Advantages:**
- **Distributed**: No single point of failure
- **Trustless**: No need to trust a central authority
- **Immutable**: Records cannot be deleted or altered
- **Multi-Party**: Each org maintains its own peer (no shared database)

### Q6: "What if two organizations disagree about evidence status?"

**Answer:**
- **Consensus**: All peers must agree on transaction order (orderer ensures this)
- **Endorsement Policy**: Multiple peers must endorse transactions (prevents fraud)
- **State Machine**: Evidence status follows defined transitions (cannot skip states)
- **Audit Trail**: Complete history shows who changed what and when
- **Dispute Resolution**: Full audit trail provides evidence for resolution

**Example:**
If Law Enforcement says evidence is "IN_CUSTODY" but Forensic Lab says it's "IN_ANALYSIS", the blockchain shows the exact transfer transaction with timestamp and TXID, proving who has custody.

### Q7: "How do you handle key management in production?"

**Answer:**
**Current (Demo):**
- Master key in environment variable
- Keys derived using HKDF (Hash-based Key Derivation Function)
- Keys cached in memory

**Production (Recommended):**
- **HSM** (Hardware Security Module): Physical device for key storage
- **Key Management Service**: AWS KMS, Azure Key Vault, HashiCorp Vault
- **Key Rotation**: Regularly rotate master keys
- **Access Control**: Limit who can access keys
- **Audit Logging**: Log all key access

**Our Code is Ready:**
- `getKey()` function can be modified to call HSM/KMS
- Key ID system already in place
- No code changes needed, just swap key storage backend

### Q8: "What's the difference between IPFS CID and SHA-256 hash?"

**Answer:**
- **SHA-256 Hash**: Hash of the **original, unencrypted** file. Used for integrity verification.
- **IPFS CID**: Hash of the **encrypted file package** (includes encrypted data, IV, auth tag). Used to retrieve file from IPFS.

**Why Both?**
- **SHA-256**: Verify original file hasn't been tampered with (compare decrypted file)
- **CID**: Locate and retrieve encrypted file from IPFS

**Example:**
```
Original File: document.pdf
SHA-256: abc123... (stored on blockchain for verification)
↓ Encrypt
Encrypted Package: {data: "...", iv: "...", authTag: "..."}
IPFS CID: QmXyZ... (stored on blockchain for retrieval)
```

### Q9: "How does the system prevent evidence tampering?"

**Answer:**
**Multiple Layers:**

1. **Encryption**: File is encrypted before storage (AES-256-GCM)
2. **Hash Verification**: Original hash stored on blockchain
3. **Immutability**: Hash on blockchain cannot be changed
4. **Access Control**: Only authorized users can access
5. **Audit Trail**: All access is logged

**Tampering Scenarios:**

**Scenario 1: Someone modifies IPFS file**
- CID changes (content-addressed)
- Stored CID on blockchain doesn't match
- System detects mismatch when retrieving

**Scenario 2: Someone modifies decrypted file**
- SHA-256 hash changes
- Doesn't match hash on blockchain
- Integrity verification fails

**Scenario 3: Someone tries to change blockchain hash**
- Requires valid certificate and permissions
- All peers must agree (consensus)
- Original transaction remains in history
- New fraudulent transaction is detectable

### Q10: "What happens during a network partition?"

**Answer:**
**Hyperledger Fabric Handles This:**

- **Raft Consensus**: Orderer uses Raft (handles network partitions)
- **Endorsement**: Transactions need endorsements from multiple peers
- **Validation**: Peers validate blocks before committing
- **Recovery**: When partition heals, peers sync missing blocks

**In Our System:**
- 3 organizations = 3 peers minimum
- If 1 peer is down, others continue
- When peer recovers, it syncs from others
- No data loss (all peers have full ledger copy)

---

## 8. Technical Implementation Details

### 8.1 Evidence Registration Code Flow

**Backend (`evidence.routes.ts`):**
```typescript
1. Receive file upload (multer)
2. Generate evidence ID: `EVD-${UUID}`
3. Compute hash: `computeHash(file.buffer)` → SHA-256
4. Generate key ID: `KEY-${UUID}`
5. Encrypt: `encryptData(file.buffer, keyId)` → AES-256-GCM
6. Upload to IPFS: `uploadEvidence(encryptedData, keyId)` → Get CID
7. Call chaincode: `registerEvidence(evidenceId, caseId, cid, hash, keyId, metadata)`
```

**Chaincode (`chaincode.go`):**
```go
1. Validate permission: `RequirePermission(ctx, PermRegisterEvidence)`
2. Check if exists: `EvidenceExists(ctx, evidenceID)`
3. Create evidence record:
   - ID, CaseID, IPFSHash (CID), EvidenceHash, EncryptionKeyID
   - Status: REGISTERED
   - CurrentCustodian: identity.ID
   - Timestamp: now
4. Store: `PutState(evidenceID, evidenceJSON)`
5. Create event: `PutState(eventKey, eventJSON)`
6. Emit event: `SetEvent("EvidenceRegistered", payload)`
```

### 8.2 Multi-Organization Gateway

**Problem:**
- Backend needs to submit transactions as different organizations
- Each org has its own X.509 certificate
- Gateway must use correct identity

**Solution:**
- Initialize separate gateway connections for each org at startup
- Store gateways in map: `gateways[orgMspId] = gateway`
- When submitting transaction, use appropriate gateway

**Code (`gateway.ts`):**
```typescript
// Initialize all org gateways
await initializeGatewayForOrg('LawEnforcementMSP');
await initializeGatewayForOrg('ForensicLabMSP');
await initializeGatewayForOrg('JudiciaryMSP');

// Get gateway for org
function getGatewayForOrg(orgMspId: string): Gateway {
  return gateways[orgMspId];
}

// Submit transaction as specific org
async function submitTransactionAsOrg(orgMspId, functionName, ...args) {
  const gateway = getGatewayForOrg(orgMspId);
  const contract = gateway.getNetwork('evidence-channel').getContract('evidence-coc');
  return contract.submitTransaction(functionName, ...args);
}
```

### 8.3 Integrity Verification Implementation

**Manual Verification (`evidence.routes.ts`):**
```typescript
POST /api/evidence/:id/verify
1. Get evidence from blockchain
2. Download from IPFS using CID
3. Decrypt using key ID
4. Compute hash of decrypted file
5. Compare with stored hash
6. Call chaincode: verifyIntegrity(evidenceId, computedHash)
7. Chaincode updates integrityVerified flag
8. Return result
```

**Automatic Verification (on download):**
```typescript
// When downloading evidence
const decryptedFile = await downloadEvidence(cid, keyId);
const computedHash = computeHash(decryptedFile);
if (computedHash !== evidence.evidenceHash) {
  // Integrity failed!
  await updateIntegrityStatus(evidenceId, false);
}
```

### 8.4 Decryption Script

**Purpose:**
- Standalone utility to decrypt evidence without using the web UI
- Useful for forensic analysis, verification, or recovery

**Usage:**
```bash
# Using evidence ID (fetches from API)
npm run decrypt -- --evidenceId EVD-123456 --token <JWT_TOKEN>

# Using direct CID and key ID
npm run decrypt -- --cid QmXyZ... --keyId KEY-123...
```

**Process:**
1. Fetch evidence details from API (if using evidenceId)
2. Download encrypted package from IPFS
3. Extract IV, auth tag, encrypted data
4. Decrypt using key ID
5. Verify hash (if stored hash available)
6. Detect file type from magic bytes
7. Save with appropriate extension

**File Type Detection:**
- Reads first bytes (magic bytes) of decrypted file
- Matches against known file signatures:
  - PDF: `%PDF`
  - PNG: `89 50 4E 47`
  - JPEG: `FF D8 FF`
  - ZIP: `50 4B 03 04`
  - etc.

---

## 9. Project Strengths & Innovations

### 9.1 What Makes This Project Strong

**1. Real-World Application**
- Solves actual problem (evidence chain of custody)
- Used by law enforcement, forensics, judiciary
- Legal and compliance requirements addressed

**2. Enterprise-Grade Technology**
- Hyperledger Fabric (industry standard for enterprise blockchain)
- Production-ready architecture
- Scalable and maintainable

**3. Security-First Design**
- Multi-layer security (network, application, blockchain, data)
- Encryption at rest and in transit
- Integrity verification built-in

**4. Complete Implementation**
- Not just a proof-of-concept
- Full-stack application (frontend, backend, blockchain, storage)
- Working demo with real workflows

**5. Best Practices**
- Role-based access control
- Immutable audit trails
- Distributed storage
- Separation of concerns (files off-chain, metadata on-chain)

### 9.2 Technical Innovations

**1. Multi-Organization Gateway**
- Backend maintains separate Fabric identities for each org
- Transactions correctly attributed to initiating organization
- Enables proper RBAC enforcement

**2. Encrypted IPFS Storage**
- Evidence encrypted before IPFS upload
- Key management separate from storage
- Content-addressed storage with encryption

**3. Integrity Verification System**
- Automatic hash verification
- Manual verification API
- Standalone decryption utility
- File type detection from magic bytes

**4. Comprehensive Audit Trail**
- Every action recorded as immutable event
- Transaction IDs for verification
- Complete custody chain visualization

**5. State Machine for Evidence Lifecycle**
- Enforced status transitions
- Prevents invalid state changes
- Clear workflow definition

### 9.3 Areas for Future Enhancement

**1. Production Key Management**
- Integrate HSM or key management service
- Key rotation policies
- Key access auditing

**2. IPFS Pinning Service**
- Commercial pinning service integration
- Redundancy and persistence guarantees
- Geographic distribution

**3. Performance Optimization**
- Caching layer for frequently accessed evidence
- Batch transaction processing
- Indexing for faster queries

**4. Advanced Features**
- Evidence versioning
- Collaborative analysis tools
- Integration with forensic tools (Autopsy, EnCase)
- Mobile app for field officers

**5. Compliance & Standards**
- NIST compliance
- ISO 27001 alignment
- Court admissibility standards

---

## 10. Quick Reference: Key Terms

| Term | Definition |
|------|------------|
| **Blockchain** | Distributed ledger that records transactions immutably |
| **Peer** | Node that maintains ledger and executes chaincode |
| **Orderer** | Node that orders transactions into blocks |
| **Chaincode** | Smart contract code that runs on blockchain |
| **MSP** | Membership Service Provider (manages org identities) |
| **Channel** | Private subnet of blockchain (data isolation) |
| **CID** | Content Identifier (IPFS hash for file location) |
| **TXID** | Transaction ID (unique identifier for blockchain transaction) |
| **RBAC** | Role-Based Access Control (permissions by role) |
| **AES-256-GCM** | Encryption algorithm (256-bit key, authenticated) |
| **SHA-256** | Cryptographic hash function (integrity verification) |
| **IPFS** | InterPlanetary File System (distributed storage) |
| **Endorsement** | Peer approval of transaction (consensus) |
| **Immutability** | Cannot be changed once written |

---

## 11. Demo Walkthrough Script

**For your presentation, follow this flow:**

1. **Start System**
   - Show network running (Docker containers)
   - Show backend and frontend running

2. **Register Evidence**
   - Login as Officer Ahmed (Law Enforcement)
   - Upload evidence file
   - Show registration success
   - Point out: Evidence ID, Hash, CID, TXID

3. **Transfer Custody**
   - Transfer to Dr. Fatima (Forensic Lab Analyst)
   - Show custody transfer event
   - Explain immutability

4. **Record Analysis**
   - Login as Dr. Fatima
   - Record analysis findings
   - Show analysis in history

5. **Submit for Review**
   - Submit to judiciary
   - Show status change

6. **Judicial Decision**
   - Login as Attorney Ali
   - Record decision (ADMITTED/REJECTED)
   - Show complete audit trail

7. **Audit Report**
   - Generate audit report
   - Show complete custody chain
   - Highlight integrity verification

8. **Integrity Verification**
   - Show "Integrity Verified" status
   - Explain hash comparison
   - Demonstrate decryption script (optional)

---




---

*Last Updated: November 2024*
*Project: Evidentia - Blockchain-Based Chain-of-Custody System*

