#!/bin/bash
# Copyright Evidentia Chain-of-Custody System
# Script to generate crypto and channel artifacts through the Fabric CLI container.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_DIR="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$NETWORK_DIR/docker"

CHANNEL_NAME="${CHANNEL_NAME:-evidence-channel}"
CHANNEL_PROFILE="${CHANNEL_PROFILE:-EvidentiaCoCChannel}"
SYSTEM_PROFILE="${SYSTEM_PROFILE:-EvidentiaCoCGenesis}"
CHANNEL_BLOCK_FILE="${CHANNEL_NAME//-/}.block"

CLI_CONTAINER_NAME="${CLI_CONTAINER_NAME:-cli}"
CLI_WORKDIR="/opt/gopath/src/github.com/hyperledger/fabric/peer"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

printInfo() { echo -e "${GREEN}[INFO]${NC} $1"; }
printWarn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
printError() { echo -e "${RED}[ERROR]${NC} $1"; }

checkPrereqs() {
  printInfo "Checking prerequisites..."

  command -v docker >/dev/null 2>&1 || { printError "docker not found"; exit 1; }
  if ! docker compose version >/dev/null 2>&1; then
    printError "docker compose v2 is required"
    exit 1
  fi
  docker info >/dev/null 2>&1 || { printError "Docker daemon is not running"; exit 1; }

  printInfo "Prerequisites check passed."
}

ensureCliContainer() {
  printInfo "Ensuring Fabric CLI container is running..."
  (
    cd "$DOCKER_DIR"
    docker compose -f docker-compose-fabric.yaml up -d --no-deps "$CLI_CONTAINER_NAME"
  )

  if ! docker ps --format '{{.Names}}' | grep -Fxq "$CLI_CONTAINER_NAME"; then
    printError "CLI container '$CLI_CONTAINER_NAME' failed to start"
    exit 1
  fi

  docker cp "$NETWORK_DIR/configtx.yaml" "${CLI_CONTAINER_NAME}:${CLI_WORKDIR}/configtx.yaml"
  docker cp "$NETWORK_DIR/crypto-config.yaml" "${CLI_CONTAINER_NAME}:${CLI_WORKDIR}/crypto-config.yaml"
}

cliExec() {
  docker exec "$CLI_CONTAINER_NAME" bash -lc "$*"
}

generateCryptoMaterials() {
  printInfo "Generating crypto materials inside CLI container..."
  rm -rf "$NETWORK_DIR/crypto-config"
  mkdir -p "$NETWORK_DIR/crypto-config"

  cliExec "
    cd '$CLI_WORKDIR'
    rm -rf ./crypto/*
    cryptogen generate --config=crypto-config.yaml --output=crypto
  "

  printInfo "Crypto materials generated successfully."
}

generateChannelArtifacts() {
  printInfo "Generating channel artifacts inside CLI container..."
  rm -rf "$NETWORK_DIR/channel-artifacts"
  mkdir -p "$NETWORK_DIR/channel-artifacts"

  cliExec "
    cd '$CLI_WORKDIR'
    export FABRIC_CFG_PATH='$CLI_WORKDIR'
    mkdir -p ./channel-artifacts

    # 1) Orderer genesis block (mounted for orderer startup)
    configtxgen -profile '$SYSTEM_PROFILE' \
      -channelID system-channel \
      -outputBlock ./channel-artifacts/genesis.block

    # 2) Legacy create-channel transaction artifact
    configtxgen -profile '$CHANNEL_PROFILE' \
      -channelID '$CHANNEL_NAME' \
      -outputCreateChannelTx ./channel-artifacts/channel.tx

    # 3) Participation API config block used by osnadmin channel join
    configtxgen -profile '$CHANNEL_PROFILE' \
      -channelID '$CHANNEL_NAME' \
      -outputBlock ./channel-artifacts/$CHANNEL_BLOCK_FILE

    # 4) Per-organization anchor peer update transactions
    configtxgen -profile '$CHANNEL_PROFILE' \
      -channelID '$CHANNEL_NAME' \
      -asOrg LawEnforcementOrg \
      -outputAnchorPeersUpdate ./channel-artifacts/LawEnforcementMSPanchors.tx

    configtxgen -profile '$CHANNEL_PROFILE' \
      -channelID '$CHANNEL_NAME' \
      -asOrg ForensicLabOrg \
      -outputAnchorPeersUpdate ./channel-artifacts/ForensicLabMSPanchors.tx

    configtxgen -profile '$CHANNEL_PROFILE' \
      -channelID '$CHANNEL_NAME' \
      -asOrg JudiciaryOrg \
      -outputAnchorPeersUpdate ./channel-artifacts/JudiciaryMSPanchors.tx
  "

  local required=(
    "$NETWORK_DIR/channel-artifacts/genesis.block"
    "$NETWORK_DIR/channel-artifacts/channel.tx"
    "$NETWORK_DIR/channel-artifacts/$CHANNEL_BLOCK_FILE"
    "$NETWORK_DIR/channel-artifacts/LawEnforcementMSPanchors.tx"
    "$NETWORK_DIR/channel-artifacts/ForensicLabMSPanchors.tx"
    "$NETWORK_DIR/channel-artifacts/JudiciaryMSPanchors.tx"
  )

  for artifact in "${required[@]}"; do
    if [[ ! -f "$artifact" ]]; then
      printError "Missing channel artifact: $artifact"
      exit 1
    fi
  done

  printInfo "Channel artifacts generated successfully."
}

copyAdminCerts() {
  printInfo "Setting up admin certificates..."
  cp "$NETWORK_DIR/crypto-config/ordererOrganizations/evidentia.network/users/Admin@evidentia.network/msp/signcerts/Admin@evidentia.network-cert.pem" \
     "$NETWORK_DIR/crypto-config/ordererOrganizations/evidentia.network/msp/admincerts/" 2>/dev/null || true
  printInfo "Admin certificates configured."
}

main() {
  printInfo "Starting Evidentia network artifact generation..."
  checkPrereqs
  ensureCliContainer
  generateCryptoMaterials
  generateChannelArtifacts
  copyAdminCerts

  printInfo "======================================"
  printInfo "Crypto + channel artifact generation complete"
  printInfo "======================================"
  printInfo "Generated in: $NETWORK_DIR/crypto-config and $NETWORK_DIR/channel-artifacts"
  printInfo "Expected channel block: $NETWORK_DIR/channel-artifacts/$CHANNEL_BLOCK_FILE"
}

main "$@"
