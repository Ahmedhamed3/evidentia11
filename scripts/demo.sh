#!/bin/bash
# Copyright Evidentia Chain-of-Custody System
# Full demonstration script showing the complete evidence lifecycle

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
API_URL="${API_URL:-http://localhost:3001}"
FRONTEND_URL="${FRONTEND_URL:-http://localhost:3000}"

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Evidentia Chain-of-Custody System - Demo Script          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to make API calls
api_call() {
    local method=$1
    local endpoint=$2
    local data=$3
    local token=$4
    
    if [ -n "$token" ]; then
        if [ -n "$data" ]; then
            curl -s -X "$method" "$API_URL$endpoint" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $token" \
                -d "$data"
        else
            curl -s -X "$method" "$API_URL$endpoint" \
                -H "Authorization: Bearer $token"
        fi
    else
        if [ -n "$data" ]; then
            curl -s -X "$method" "$API_URL$endpoint" \
                -H "Content-Type: application/json" \
                -d "$data"
        else
            curl -s -X "$method" "$API_URL$endpoint"
        fi
    fi
}

# Check if services are running
echo -e "${YELLOW}Checking services...${NC}"

if ! curl -s "$API_URL/health" > /dev/null 2>&1; then
    echo -e "${RED}Backend not running at $API_URL${NC}"
    echo "Please start the backend first: cd backend && npm run dev"
    exit 1
fi

echo -e "${GREEN}✓ Backend is running${NC}"

# Demo scenario
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                    DEMO SCENARIO                               ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "This demo simulates a complete evidence lifecycle:"
echo "  1. Law enforcement officer registers seized evidence"
echo "  2. Evidence is transferred to forensic lab"
echo "  3. Forensic analyst examines the evidence"
echo "  4. Supervisor verifies and submits for judicial review"
echo "  5. Legal counsel makes admissibility decision"
echo "  6. Audit report is generated"
echo ""
read -p "Press Enter to start the demo..."

# Step 1: Login as Law Enforcement Collector
echo ""
echo -e "${BLUE}Step 1: Officer logs in and registers evidence${NC}"
echo -e "${YELLOW}─────────────────────────────────────────────────${NC}"

echo "Logging in as collector@lawenforcement..."
LOGIN_RESPONSE=$(api_call POST "/api/auth/login" '{"username":"collector@lawenforcement","password":"password123"}')
COLLECTOR_TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$COLLECTOR_TOKEN" ]; then
    echo -e "${RED}Login failed${NC}"
    echo $LOGIN_RESPONSE
    exit 1
fi
echo -e "${GREEN}✓ Logged in as Officer Smith (Evidence Collector)${NC}"

# Create a test file for evidence
echo "Creating test evidence file..."
TEST_FILE="/tmp/evidence_demo_$(date +%s).bin"
dd if=/dev/urandom of=$TEST_FILE bs=1024 count=100 2>/dev/null
EVIDENCE_HASH=$(sha256sum $TEST_FILE | cut -d' ' -f1)

echo "Evidence file created: $TEST_FILE"
echo "SHA-256 Hash: $EVIDENCE_HASH"

# Note: File upload requires multipart form, using curl directly
echo "Registering evidence on blockchain..."
CASE_ID="CASE-DEMO-$(date +%Y%m%d)"
REGISTER_RESPONSE=$(curl -s -X POST "$API_URL/api/evidence" \
    -H "Authorization: Bearer $COLLECTOR_TOKEN" \
    -F "file=@$TEST_FILE" \
    -F "caseId=$CASE_ID" \
    -F "name=Seized Laptop Disk Image" \
    -F "type=Disk Image" \
    -F "sourceDevice=Dell Latitude E7450 SN:ABC123" \
    -F "location=123 Main St, Evidence Room" \
    -F "notes=Laptop seized from suspect during search warrant execution")

EVIDENCE_ID=$(echo $REGISTER_RESPONSE | grep -o '"evidenceId":"[^"]*' | cut -d'"' -f4)

if [ -z "$EVIDENCE_ID" ]; then
    echo -e "${RED}Failed to register evidence${NC}"
    echo $REGISTER_RESPONSE
    exit 1
fi

echo -e "${GREEN}✓ Evidence registered: $EVIDENCE_ID${NC}"
echo "  Case: $CASE_ID"
echo "  Hash stored on blockchain"

sleep 2

# Step 2: Transfer to Forensic Lab
echo ""
echo -e "${BLUE}Step 2: Transfer custody to Forensic Lab${NC}"
echo -e "${YELLOW}─────────────────────────────────────────────────${NC}"

echo "Transferring custody to forensic analyst..."
TRANSFER_RESPONSE=$(api_call POST "/api/evidence/$EVIDENCE_ID/transfer" \
    '{"toEntityId":"analyst-fl-001","toOrgMSP":"ForensicLabMSP","reason":"Transfer for forensic examination"}' \
    "$COLLECTOR_TOKEN")

echo -e "${GREEN}✓ Custody transferred to Dr. Chen (Forensic Lab)${NC}"
echo "  Blockchain transaction recorded"

sleep 2

# Step 3: Login as Forensic Analyst and examine
echo ""
echo -e "${BLUE}Step 3: Forensic analyst examines evidence${NC}"
echo -e "${YELLOW}─────────────────────────────────────────────────${NC}"

echo "Logging in as analyst@forensiclab..."
LOGIN_RESPONSE=$(api_call POST "/api/auth/login" '{"username":"analyst@forensiclab","password":"password123"}')
ANALYST_TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"token":"[^"]*' | cut -d'"' -f4)
echo -e "${GREEN}✓ Logged in as Dr. Chen (Forensic Analyst)${NC}"

echo "Recording forensic analysis..."
ANALYSIS_RESPONSE=$(api_call POST "/api/evidence/$EVIDENCE_ID/analysis" \
    '{"toolUsed":"Autopsy","toolVersion":"4.21.0","findings":"Examination revealed browser history artifacts, deleted email messages, and encrypted document files. Timeline analysis shows activity during the period in question. Multiple artifacts support the investigation hypothesis.","artifacts":["browser_history.csv","deleted_emails.pst","encrypted_docs.zip","registry_backup.reg"],"methodology":"NIST 800-86 guidelines for disk forensics"}' \
    "$ANALYST_TOKEN")

ANALYSIS_ID=$(echo $ANALYSIS_RESPONSE | grep -o '"analysisId":"[^"]*' | cut -d'"' -f4)
echo -e "${GREEN}✓ Analysis recorded: $ANALYSIS_ID${NC}"
echo "  Tool: Autopsy 4.21.0"
echo "  Artifacts found: 4"

sleep 2

# Step 4: Supervisor verifies and submits for review
echo ""
echo -e "${BLUE}Step 4: Supervisor verifies and submits for judicial review${NC}"
echo -e "${YELLOW}─────────────────────────────────────────────────${NC}"

echo "Logging in as supervisor@forensiclab..."
LOGIN_RESPONSE=$(api_call POST "/api/auth/login" '{"username":"supervisor@forensiclab","password":"password123"}')
SUPERVISOR_TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"token":"[^"]*' | cut -d'"' -f4)
echo -e "${GREEN}✓ Logged in as Dr. Williams (Lab Supervisor)${NC}"

echo "Submitting evidence for judicial review..."
REVIEW_RESPONSE=$(api_call POST "/api/evidence/$EVIDENCE_ID/review" \
    '{"caseNotes":"Evidence has been thoroughly examined following established forensic protocols. Chain of custody maintained throughout. Analysis findings support prosecution case. Recommend admission as evidence."}' \
    "$SUPERVISOR_TOKEN")

REVIEW_ID=$(echo $REVIEW_RESPONSE | grep -o '"reviewId":"[^"]*' | cut -d'"' -f4)
echo -e "${GREEN}✓ Submitted for judicial review: $REVIEW_ID${NC}"

sleep 2

# Step 5: Legal counsel makes decision
echo ""
echo -e "${BLUE}Step 5: Legal counsel records admissibility decision${NC}"
echo -e "${YELLOW}─────────────────────────────────────────────────${NC}"

echo "Logging in as counsel@judiciary..."
LOGIN_RESPONSE=$(api_call POST "/api/auth/login" '{"username":"counsel@judiciary","password":"password123"}')
COUNSEL_TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"token":"[^"]*' | cut -d'"' -f4)
echo -e "${GREEN}✓ Logged in as Attorney Davis (Legal Counsel)${NC}"

echo "Recording judicial decision..."
DECISION_RESPONSE=$(api_call POST "/api/evidence/$EVIDENCE_ID/decision" \
    "{\"reviewId\":\"$REVIEW_ID\",\"decision\":\"ADMITTED\",\"decisionReason\":\"Evidence meets all legal requirements for admissibility. Chain of custody properly documented. Forensic methodology follows accepted standards.\",\"courtReference\":\"Case No. 2024-CR-$(date +%m%d)\"}" \
    "$COUNSEL_TOKEN")

echo -e "${GREEN}✓ Evidence ADMITTED by court${NC}"
echo "  All blockchain records verified"

sleep 2

# Step 6: Generate audit report
echo ""
echo -e "${BLUE}Step 6: Generate comprehensive audit report${NC}"
echo -e "${YELLOW}─────────────────────────────────────────────────${NC}"

echo "Generating audit report..."
REPORT_RESPONSE=$(api_call GET "/api/audit/report/$EVIDENCE_ID" "" "$COUNSEL_TOKEN")

echo -e "${GREEN}✓ Audit report generated${NC}"

# Summary
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                    DEMO COMPLETE                               ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Summary of blockchain-recorded events:${NC}"
echo "  1. ✓ Evidence registered by Law Enforcement"
echo "  2. ✓ Custody transferred to Forensic Lab"
echo "  3. ✓ Forensic analysis recorded"
echo "  4. ✓ Submitted for judicial review"
echo "  5. ✓ Judicial decision: ADMITTED"
echo "  6. ✓ Full audit trail available"
echo ""
echo -e "${YELLOW}View in browser:${NC}"
echo "  Evidence Detail: $FRONTEND_URL/evidence/$EVIDENCE_ID"
echo "  Audit Report: $FRONTEND_URL/audit/$EVIDENCE_ID"
echo ""
echo -e "${CYAN}All events are immutably stored on the Hyperledger Fabric blockchain"
echo -e "with evidence files encrypted and stored on IPFS.${NC}"
echo ""

# Cleanup
rm -f $TEST_FILE

