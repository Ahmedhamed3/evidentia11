#!/bin/bash
# Copyright Evidentia Chain-of-Custody System
# Script to deploy the evidence-coc chaincode

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$NETWORK_DIR")"

CHANNEL_NAME="evidence-channel"
CHAINCODE_NAME="evidence-coc"
CHAINCODE_VERSION="1.0"
CHAINCODE_SEQUENCE=1
CHAINCODE_PATH="$PROJECT_ROOT/chaincode/evidence-coc"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function printInfo() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function printWarn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function printError() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Set environment for Law Enforcement peer (for packaging)
function setLawEnforcementEnv() {
    export CORE_PEER_LOCALMSPID="LawEnforcementMSP"
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_TLS_ROOTCERT_FILE="$NETWORK_DIR/crypto-config/peerOrganizations/lawenforcement.evidentia.network/peers/peer0.lawenforcement.evidentia.network/tls/ca.crt"
    export CORE_PEER_MSPCONFIGPATH="$NETWORK_DIR/crypto-config/peerOrganizations/lawenforcement.evidentia.network/users/Admin@lawenforcement.evidentia.network/msp"
    export CORE_PEER_ADDRESS="localhost:7051"
}

# Set environment for Forensic Lab peer
function setForensicLabEnv() {
    export CORE_PEER_LOCALMSPID="ForensicLabMSP"
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_TLS_ROOTCERT_FILE="$NETWORK_DIR/crypto-config/peerOrganizations/forensiclab.evidentia.network/peers/peer0.forensiclab.evidentia.network/tls/ca.crt"
    export CORE_PEER_MSPCONFIGPATH="$NETWORK_DIR/crypto-config/peerOrganizations/forensiclab.evidentia.network/users/Admin@forensiclab.evidentia.network/msp"
    export CORE_PEER_ADDRESS="localhost:9051"
}

# Set environment for Judiciary peer
function setJudiciaryEnv() {
    export CORE_PEER_LOCALMSPID="JudiciaryMSP"
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_TLS_ROOTCERT_FILE="$NETWORK_DIR/crypto-config/peerOrganizations/judiciary.evidentia.network/peers/peer0.judiciary.evidentia.network/tls/ca.crt"
    export CORE_PEER_MSPCONFIGPATH="$NETWORK_DIR/crypto-config/peerOrganizations/judiciary.evidentia.network/users/Admin@judiciary.evidentia.network/msp"
    export CORE_PEER_ADDRESS="localhost:11051"
}

# Package chaincode
function packageChaincode() {
    printInfo "Packaging chaincode..."
    
    cd "$CHAINCODE_PATH"
    
    # Ensure Go modules are vendored
    printInfo "Vendoring Go modules..."
    GO111MODULE=on go mod vendor
    
    cd "$NETWORK_DIR"
    
    # Remove existing package if present
    rm -f "${CHAINCODE_NAME}.tar.gz"
    
    setLawEnforcementEnv
    
    peer lifecycle chaincode package "${CHAINCODE_NAME}.tar.gz" \
        --path "$CHAINCODE_PATH" \
        --lang golang \
        --label "${CHAINCODE_NAME}_${CHAINCODE_VERSION}"
    
    if [ $? -ne 0 ]; then
        printError "Failed to package chaincode"
        exit 1
    fi
    
    printInfo "Chaincode packaged: ${CHAINCODE_NAME}.tar.gz"
}

# Install chaincode on a peer
function installChaincode() {
    local ORG_NAME=$1
    
    printInfo "Installing chaincode on $ORG_NAME peer..."
    
    # Set the right environment
    case $ORG_NAME in
        "LawEnforcement")
            setLawEnforcementEnv
            ;;
        "ForensicLab")
            setForensicLabEnv
            ;;
        "Judiciary")
            setJudiciaryEnv
            ;;
    esac
    
    cd "$NETWORK_DIR"
    
    peer lifecycle chaincode install "${CHAINCODE_NAME}.tar.gz"
    
    if [ $? -ne 0 ]; then
        printError "Failed to install chaincode on $ORG_NAME"
        exit 1
    fi
    
    printInfo "Chaincode installed on $ORG_NAME"
}

# Get package ID
function getPackageId() {
    setLawEnforcementEnv
    
    PACKAGE_ID=$(peer lifecycle chaincode queryinstalled | grep "${CHAINCODE_NAME}_${CHAINCODE_VERSION}" | awk -F "[, ]+" '{print $3}')
    
    if [ -z "$PACKAGE_ID" ]; then
        printError "Failed to get package ID"
        exit 1
    fi
    
    printInfo "Package ID: $PACKAGE_ID"
    export PACKAGE_ID
}

# Approve chaincode for an organization
function approveChaincode() {
    local ORG_NAME=$1
    
    printInfo "Approving chaincode for $ORG_NAME..."
    
    # Set the right environment
    case $ORG_NAME in
        "LawEnforcement")
            setLawEnforcementEnv
            ;;
        "ForensicLab")
            setForensicLabEnv
            ;;
        "Judiciary")
            setJudiciaryEnv
            ;;
    esac
    
    local ORDERER_TLS_CA="$NETWORK_DIR/crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/msp/tlscacerts/tlsca.evidentia.network-cert.pem"
    
    peer lifecycle chaincode approveformyorg \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.evidentia.network \
        --channelID "$CHANNEL_NAME" \
        --name "$CHAINCODE_NAME" \
        --version "$CHAINCODE_VERSION" \
        --package-id "$PACKAGE_ID" \
        --sequence "$CHAINCODE_SEQUENCE" \
        --tls \
        --cafile "$ORDERER_TLS_CA" \
        --collections-config "$NETWORK_DIR/collections_config.json"
    
    if [ $? -ne 0 ]; then
        printError "Failed to approve chaincode for $ORG_NAME"
        exit 1
    fi
    
    printInfo "Chaincode approved for $ORG_NAME"
}

# Check commit readiness
function checkCommitReadiness() {
    printInfo "Checking commit readiness..."
    
    setLawEnforcementEnv
    
    local ORDERER_TLS_CA="$NETWORK_DIR/crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/msp/tlscacerts/tlsca.evidentia.network-cert.pem"
    
    peer lifecycle chaincode checkcommitreadiness \
        --channelID "$CHANNEL_NAME" \
        --name "$CHAINCODE_NAME" \
        --version "$CHAINCODE_VERSION" \
        --sequence "$CHAINCODE_SEQUENCE" \
        --tls \
        --cafile "$ORDERER_TLS_CA" \
        --collections-config "$NETWORK_DIR/collections_config.json" \
        --output json
}

# Commit chaincode
function commitChaincode() {
    printInfo "Committing chaincode to channel..."
    
    setLawEnforcementEnv
    
    local ORDERER_TLS_CA="$NETWORK_DIR/crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/msp/tlscacerts/tlsca.evidentia.network-cert.pem"
    local LE_TLS_CA="$NETWORK_DIR/crypto-config/peerOrganizations/lawenforcement.evidentia.network/peers/peer0.lawenforcement.evidentia.network/tls/ca.crt"
    local FL_TLS_CA="$NETWORK_DIR/crypto-config/peerOrganizations/forensiclab.evidentia.network/peers/peer0.forensiclab.evidentia.network/tls/ca.crt"
    local JD_TLS_CA="$NETWORK_DIR/crypto-config/peerOrganizations/judiciary.evidentia.network/peers/peer0.judiciary.evidentia.network/tls/ca.crt"
    
    peer lifecycle chaincode commit \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.evidentia.network \
        --channelID "$CHANNEL_NAME" \
        --name "$CHAINCODE_NAME" \
        --version "$CHAINCODE_VERSION" \
        --sequence "$CHAINCODE_SEQUENCE" \
        --tls \
        --cafile "$ORDERER_TLS_CA" \
        --peerAddresses localhost:7051 \
        --tlsRootCertFiles "$LE_TLS_CA" \
        --peerAddresses localhost:9051 \
        --tlsRootCertFiles "$FL_TLS_CA" \
        --peerAddresses localhost:11051 \
        --tlsRootCertFiles "$JD_TLS_CA" \
        --collections-config "$NETWORK_DIR/collections_config.json"
    
    if [ $? -ne 0 ]; then
        printError "Failed to commit chaincode"
        exit 1
    fi
    
    printInfo "Chaincode committed successfully"
}

# Query committed chaincode
function queryCommitted() {
    printInfo "Querying committed chaincode..."
    
    setLawEnforcementEnv
    
    peer lifecycle chaincode querycommitted \
        --channelID "$CHANNEL_NAME" \
        --name "$CHAINCODE_NAME"
}

# Initialize chaincode (if needed)
function initChaincode() {
    printInfo "Initializing chaincode..."
    
    setLawEnforcementEnv
    
    local ORDERER_TLS_CA="$NETWORK_DIR/crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/msp/tlscacerts/tlsca.evidentia.network-cert.pem"
    local LE_TLS_CA="$NETWORK_DIR/crypto-config/peerOrganizations/lawenforcement.evidentia.network/peers/peer0.lawenforcement.evidentia.network/tls/ca.crt"
    
    peer chaincode invoke \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.evidentia.network \
        --channelID "$CHANNEL_NAME" \
        --name "$CHAINCODE_NAME" \
        -c '{"function":"InitLedger","Args":[]}' \
        --tls \
        --cafile "$ORDERER_TLS_CA" \
        --peerAddresses localhost:7051 \
        --tlsRootCertFiles "$LE_TLS_CA"
    
    printInfo "Chaincode initialized"
}

# Main function
function main() {
    printInfo "======================================"
    printInfo "Deploying Evidence CoC Chaincode"
    printInfo "======================================"
    
    # Package chaincode
    packageChaincode
    
    # Install on all peers
    installChaincode "LawEnforcement"
    installChaincode "ForensicLab"
    installChaincode "Judiciary"
    
    # Get package ID
    getPackageId
    
    # Approve for all orgs
    approveChaincode "LawEnforcement"
    approveChaincode "ForensicLab"
    approveChaincode "Judiciary"
    
    # Check readiness
    checkCommitReadiness
    
    # Commit
    commitChaincode
    
    # Query to verify
    queryCommitted
    
    # Initialize (optional, if chaincode has init function)
    # initChaincode
    
    printInfo "======================================"
    printInfo "Chaincode Deployment Complete!"
    printInfo "======================================"
    printInfo ""
    printInfo "Chaincode: $CHAINCODE_NAME"
    printInfo "Version: $CHAINCODE_VERSION"
    printInfo "Channel: $CHANNEL_NAME"
    printInfo ""
    printInfo "The chaincode is now ready for use."
    printInfo "Next step: Start the backend server"
}

main "$@"

