#!/bin/bash
# Copyright Evidentia Chain-of-Custody System
# Script to start/stop the Fabric network

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_DIR="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$NETWORK_DIR/docker"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

function printStep() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check Docker prerequisites
function checkPrereqs() {
    printInfo "Checking Docker prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        printError "Docker not found. Please install Docker."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        printError "Docker Compose not found. Please install Docker Compose."
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        printError "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    
    printInfo "Docker prerequisites check passed."
}

# Start the network
function networkUp() {
    printStep "Starting Evidentia CoC Network..."
    
    cd "$DOCKER_DIR"
    
    # Check if crypto materials exist
    if [ ! -d "$NETWORK_DIR/crypto-config" ]; then
        printError "Crypto materials not found. Run ./scripts/generate.sh first."
        exit 1
    fi
    
    # Start CouchDB containers first
    printInfo "Starting CouchDB containers..."
    docker-compose -f docker-compose-couch.yaml up -d
    
    # Wait for CouchDB to be ready
    printInfo "Waiting for CouchDB to be ready..."
    sleep 5
    
    # Start Fabric network
    printInfo "Starting Fabric containers..."
    docker-compose -f docker-compose-fabric.yaml up -d
    
    # Wait for network to stabilize
    printInfo "Waiting for network to stabilize..."
    sleep 10
    
    # Start IPFS
    printInfo "Starting IPFS node..."
    docker-compose -f docker-compose-ipfs.yaml up -d
    
    # Wait for IPFS
    sleep 5
    
    printInfo "======================================"
    printInfo "Evidentia Network Started Successfully!"
    printInfo "======================================"
    printInfo ""
    printInfo "Services running:"
    printInfo "  - Orderer: localhost:7050"
    printInfo "  - LawEnforcement Peer: localhost:7051"
    printInfo "  - ForensicLab Peer: localhost:9051"
    printInfo "  - Judiciary Peer: localhost:11051"
    printInfo "  - CouchDB (LawEnforcement): localhost:5984"
    printInfo "  - CouchDB (ForensicLab): localhost:6984"
    printInfo "  - CouchDB (Judiciary): localhost:7984"
    printInfo "  - IPFS API: localhost:5001"
    printInfo "  - IPFS Gateway: localhost:8080"
    printInfo ""
    printInfo "Next step: Run ./scripts/channel.sh to create the channel"
}

# Stop the network
function networkDown() {
    printStep "Stopping Evidentia CoC Network..."
    
    cd "$DOCKER_DIR"
    
    # Stop all containers
    printInfo "Stopping containers..."
    docker-compose -f docker-compose-ipfs.yaml down --volumes --remove-orphans 2>/dev/null || true
    docker-compose -f docker-compose-fabric.yaml down --volumes --remove-orphans 2>/dev/null || true
    docker-compose -f docker-compose-couch.yaml down --volumes --remove-orphans 2>/dev/null || true
    
    # Remove chaincode containers if any
    printInfo "Removing chaincode containers..."
    docker rm -f $(docker ps -aq --filter "name=dev-peer*") 2>/dev/null || true
    docker rm -f $(docker ps -aq --filter "name=evidence-coc*") 2>/dev/null || true
    
    # Remove chaincode images
    printInfo "Removing chaincode images..."
    docker rmi -f $(docker images -q --filter "reference=dev-peer*") 2>/dev/null || true
    
    printInfo "Network stopped."
}

# Restart the network
function networkRestart() {
    printStep "Restarting Evidentia CoC Network..."
    networkDown
    sleep 3
    networkUp
}

# Show network status
function networkStatus() {
    printStep "Evidentia Network Status"
    echo ""
    
    printInfo "Docker containers:"
    docker ps --filter "label=service=hyperledger-fabric" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo ""
    printInfo "IPFS container:"
    docker ps --filter "name=ipfs" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# Clean up everything including crypto materials
function networkClean() {
    printStep "Cleaning up Evidentia network..."
    
    networkDown
    
    cd "$NETWORK_DIR"
    
    printWarn "Removing crypto materials..."
    rm -rf crypto-config
    
    printWarn "Removing channel artifacts..."
    rm -rf channel-artifacts
    
    printInfo "Cleanup complete."
}

# Print usage
function printHelp() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  up       - Start the network"
    echo "  down     - Stop the network"
    echo "  restart  - Restart the network"
    echo "  status   - Show network status"
    echo "  clean    - Stop and remove all artifacts"
    echo ""
}

# Main
checkPrereqs

case "$1" in
    up)
        networkUp
        ;;
    down)
        networkDown
        ;;
    restart)
        networkRestart
        ;;
    status)
        networkStatus
        ;;
    clean)
        networkClean
        ;;
    *)
        printHelp
        exit 1
        ;;
esac

