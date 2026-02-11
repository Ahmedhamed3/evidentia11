#!/bin/bash
# Copyright Evidentia Chain-of-Custody System
# Environment variables helper script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_DIR="$(dirname "$SCRIPT_DIR")"

# Export common variables
export FABRIC_CFG_PATH="$NETWORK_DIR/peercfg"
export CHANNEL_NAME="evidence-channel"

# Function to set environment for a specific organization and user
function setOrgEnv() {
    local ORG=$1
    local USER=${2:-Admin}
    
    case $ORG in
        "LawEnforcement"|"lawenforcement"|"1")
            export CORE_PEER_LOCALMSPID="LawEnforcementMSP"
            export CORE_PEER_TLS_ENABLED=true
            export CORE_PEER_TLS_ROOTCERT_FILE="$NETWORK_DIR/crypto-config/peerOrganizations/lawenforcement.evidentia.network/peers/peer0.lawenforcement.evidentia.network/tls/ca.crt"
            export CORE_PEER_MSPCONFIGPATH="$NETWORK_DIR/crypto-config/peerOrganizations/lawenforcement.evidentia.network/users/${USER}@lawenforcement.evidentia.network/msp"
            export CORE_PEER_ADDRESS="localhost:7051"
            ;;
        "ForensicLab"|"forensiclab"|"2")
            export CORE_PEER_LOCALMSPID="ForensicLabMSP"
            export CORE_PEER_TLS_ENABLED=true
            export CORE_PEER_TLS_ROOTCERT_FILE="$NETWORK_DIR/crypto-config/peerOrganizations/forensiclab.evidentia.network/peers/peer0.forensiclab.evidentia.network/tls/ca.crt"
            export CORE_PEER_MSPCONFIGPATH="$NETWORK_DIR/crypto-config/peerOrganizations/forensiclab.evidentia.network/users/${USER}@forensiclab.evidentia.network/msp"
            export CORE_PEER_ADDRESS="localhost:9051"
            ;;
        "Judiciary"|"judiciary"|"3")
            export CORE_PEER_LOCALMSPID="JudiciaryMSP"
            export CORE_PEER_TLS_ENABLED=true
            export CORE_PEER_TLS_ROOTCERT_FILE="$NETWORK_DIR/crypto-config/peerOrganizations/judiciary.evidentia.network/peers/peer0.judiciary.evidentia.network/tls/ca.crt"
            export CORE_PEER_MSPCONFIGPATH="$NETWORK_DIR/crypto-config/peerOrganizations/judiciary.evidentia.network/users/${USER}@judiciary.evidentia.network/msp"
            export CORE_PEER_ADDRESS="localhost:11051"
            ;;
        "Orderer"|"orderer"|"0")
            export CORE_PEER_LOCALMSPID="OrdererMSP"
            export CORE_PEER_TLS_ROOTCERT_FILE="$NETWORK_DIR/crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/tls/ca.crt"
            export CORE_PEER_MSPCONFIGPATH="$NETWORK_DIR/crypto-config/ordererOrganizations/evidentia.network/users/${USER}@evidentia.network/msp"
            ;;
        *)
            echo "Unknown organization: $ORG"
            echo "Usage: setOrgEnv <LawEnforcement|ForensicLab|Judiciary|Orderer> [User]"
            return 1
            ;;
    esac
    
    export ORDERER_CA="$NETWORK_DIR/crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/msp/tlscacerts/tlsca.evidentia.network-cert.pem"
}

# Export the function
export -f setOrgEnv

