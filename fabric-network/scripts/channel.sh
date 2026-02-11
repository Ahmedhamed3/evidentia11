#!/bin/bash
# Copyright Evidentia Chain-of-Custody System
# Script to create and join channel

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_DIR="$(dirname "$SCRIPT_DIR")"

CHANNEL_NAME="evidence-channel"
DELAY=3
MAX_RETRY=5

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

# Set environment for orderer admin
function setOrdererEnv() {
    export CORE_PEER_LOCALMSPID="OrdererMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE="$NETWORK_DIR/crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/tls/ca.crt"
    export CORE_PEER_MSPCONFIGPATH="$NETWORK_DIR/crypto-config/ordererOrganizations/evidentia.network/users/Admin@evidentia.network/msp"
    export ORDERER_CA="$NETWORK_DIR/crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/msp/tlscacerts/tlsca.evidentia.network-cert.pem"
    export ORDERER_ADMIN_TLS_SIGN_CERT="$NETWORK_DIR/crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/tls/server.crt"
    export ORDERER_ADMIN_TLS_PRIVATE_KEY="$NETWORK_DIR/crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/tls/server.key"
}

# Set environment for Law Enforcement peer
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

# Create channel
function createChannel() {
    printInfo "Creating channel: $CHANNEL_NAME"
    
    setOrdererEnv
    
    local ORDERER_TLS_CA="$NETWORK_DIR/crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/msp/tlscacerts/tlsca.evidentia.network-cert.pem"
    
    osnadmin channel join \
        --channelID "$CHANNEL_NAME" \
        --config-block "$NETWORK_DIR/channel-artifacts/evidencechannel.block" \
        -o localhost:7053 \
        --ca-file "$ORDERER_TLS_CA" \
        --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" \
        --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY"
    
    if [ $? -ne 0 ]; then
        printError "Failed to create channel"
        exit 1
    fi
    
    printInfo "Channel $CHANNEL_NAME created successfully"
}

# Join peer to channel
function joinChannel() {
    local ORG_NAME=$1
    
    printInfo "Joining $ORG_NAME peer to channel..."
    
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
    
    # Retry loop
    for i in $(seq 1 $MAX_RETRY); do
        peer channel join \
            -b "$NETWORK_DIR/channel-artifacts/evidencechannel.block" \
            --tls \
            --cafile "$ORDERER_TLS_CA"
        
        if [ $? -eq 0 ]; then
            printInfo "$ORG_NAME peer joined channel successfully"
            return 0
        fi
        
        printWarn "Join failed, retrying in $DELAY seconds... (attempt $i/$MAX_RETRY)"
        sleep $DELAY
    done
    
    printError "Failed to join $ORG_NAME peer to channel after $MAX_RETRY attempts"
    exit 1
}

# Set anchor peer for an organization
function setAnchorPeer() {
    local ORG_NAME=$1
    local ORG_MSP="${ORG_NAME}MSP"
    
    printInfo "Setting anchor peer for $ORG_NAME..."
    
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
    
    # Fetch the latest config block
    peer channel fetch config config_block.pb \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.evidentia.network \
        -c "$CHANNEL_NAME" \
        --tls \
        --cafile "$ORDERER_TLS_CA"
    
    printInfo "Anchor peer configuration complete for $ORG_NAME"
}

# List channels
function listChannels() {
    printInfo "Listing channels on orderer..."
    
    setOrdererEnv
    
    local ORDERER_TLS_CA="$NETWORK_DIR/crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/msp/tlscacerts/tlsca.evidentia.network-cert.pem"
    
    osnadmin channel list \
        -o localhost:7053 \
        --ca-file "$ORDERER_TLS_CA" \
        --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" \
        --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY"
}

# Main function
function main() {
    printInfo "======================================"
    printInfo "Creating and Joining Evidence Channel"
    printInfo "======================================"
    
    # Create the channel
    createChannel
    
    sleep $DELAY
    
    # Join all peers
    joinChannel "LawEnforcement"
    sleep $DELAY
    
    joinChannel "ForensicLab"
    sleep $DELAY
    
    joinChannel "Judiciary"
    sleep $DELAY
    
    # List channels to verify
    listChannels
    
    printInfo "======================================"
    printInfo "Channel Setup Complete!"
    printInfo "======================================"
    printInfo ""
    printInfo "All peers have joined the channel: $CHANNEL_NAME"
    printInfo ""
    printInfo "Next step: Run ./scripts/deploy-chaincode.sh to deploy the chaincode"
}

# Check command
case "$1" in
    create)
        createChannel
        ;;
    join)
        if [ -z "$2" ]; then
            printError "Usage: $0 join <OrgName>"
            exit 1
        fi
        joinChannel "$2"
        ;;
    list)
        listChannels
        ;;
    *)
        main
        ;;
esac

