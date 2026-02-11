#!/bin/bash
# Copyright Evidentia Chain-of-Custody System
# Script to generate crypto materials for the network

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function printInfo() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function printWarn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function printError() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if cryptogen and configtxgen are available
function checkPrereqs() {
    printInfo "Checking prerequisites..."
    
    if ! command -v cryptogen &> /dev/null; then
        printError "cryptogen not found. Please install Fabric binaries."
        printInfo "Run: curl -sSLO https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh && chmod +x install-fabric.sh"
        printInfo "Then: ./install-fabric.sh binary"
        exit 1
    fi
    
    if ! command -v configtxgen &> /dev/null; then
        printError "configtxgen not found. Please install Fabric binaries."
        exit 1
    fi
    
    printInfo "Prerequisites check passed."
}

# Generate crypto materials using cryptogen
function generateCryptoMaterials() {
    printInfo "Generating crypto materials..."
    
    cd "$NETWORK_DIR"
    
    # Remove existing crypto materials
    if [ -d "crypto-config" ]; then
        printWarn "Removing existing crypto-config directory..."
        rm -rf crypto-config
    fi
    
    # Generate crypto materials
    cryptogen generate --config=crypto-config.yaml --output=crypto-config
    
    if [ $? -ne 0 ]; then
        printError "Failed to generate crypto materials"
        exit 1
    fi
    
    printInfo "Crypto materials generated successfully."
}

# Generate genesis block and channel configuration
function generateChannelArtifacts() {
    printInfo "Generating channel artifacts..."
    
    cd "$NETWORK_DIR"
    
    # Create channel-artifacts directory
    mkdir -p channel-artifacts
    
    # Set FABRIC_CFG_PATH to current directory
    export FABRIC_CFG_PATH="$NETWORK_DIR"
    
    # Generate genesis block for evidence-channel
    printInfo "Generating genesis block..."
    configtxgen -profile EvidentiaCoCGenesis -outputBlock ./channel-artifacts/evidencechannel.block -channelID evidence-channel
    
    if [ $? -ne 0 ]; then
        printError "Failed to generate genesis block"
        exit 1
    fi
    
    printInfo "Channel artifacts generated successfully."
}

# Copy admin certs for TLS
function copyAdminCerts() {
    printInfo "Setting up admin certificates..."
    
    cd "$NETWORK_DIR"
    
    # Copy orderer admin certs
    cp crypto-config/ordererOrganizations/evidentia.network/users/Admin@evidentia.network/msp/signcerts/Admin@evidentia.network-cert.pem \
       crypto-config/ordererOrganizations/evidentia.network/msp/admincerts/ 2>/dev/null || true
    
    printInfo "Admin certificates configured."
}

# Main execution
function main() {
    printInfo "Starting Evidentia network crypto material generation..."
    
    checkPrereqs
    generateCryptoMaterials
    generateChannelArtifacts
    copyAdminCerts
    
    printInfo "======================================"
    printInfo "Crypto material generation complete!"
    printInfo "======================================"
    printInfo ""
    printInfo "Generated files:"
    printInfo "  - crypto-config/ (certificates and keys)"
    printInfo "  - channel-artifacts/ (genesis block)"
    printInfo ""
    printInfo "Next step: Run ./scripts/network.sh up"
}

main "$@"

