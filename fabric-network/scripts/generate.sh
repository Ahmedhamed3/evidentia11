#!/bin/bash
# Copyright Evidentia Chain-of-Custody System
# Generate crypto material and channel artifacts from inside the Fabric tools (CLI) container.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_DIR="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$NETWORK_DIR/docker"

CHANNEL_NAME="${CHANNEL_NAME:-evidence-channel}"
CHANNEL_PROFILE="${CHANNEL_PROFILE:-EvidentiaCoCChannel}"
SYSTEM_PROFILE="${SYSTEM_PROFILE:-OrdererGenesis}"
CHANNEL_BLOCK_FILE="${CHANNEL_NAME//-/}.block"

CLI_CONTAINER_NAME="${CLI_CONTAINER_NAME:-cli}"
CLI_WORKDIR="/opt/gopath/src/github.com/hyperledger/fabric/peer"
CLI_CRYPTO_DIR="$CLI_WORKDIR/crypto-config"

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
  docker compose version >/dev/null 2>&1 || { printError "docker compose v2 is required"; exit 1; }
  docker info >/dev/null 2>&1 || { printError "Docker daemon is not running"; exit 1; }
}

ensureCliContainer() {
  printInfo "Ensuring Fabric CLI container is running..."
  (
    cd "$DOCKER_DIR"
    docker compose -f docker-compose-fabric.yaml up -d --no-deps "$CLI_CONTAINER_NAME"
  )

  docker ps --format '{{.Names}}' | grep -Fxq "$CLI_CONTAINER_NAME" || {
    printError "CLI container '$CLI_CONTAINER_NAME' failed to start"
    exit 1
  }

  # Keep container-side config files in sync before running cryptogen/configtxgen.
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
    rm -rf '${CLI_CRYPTO_DIR}'/*
    cryptogen generate --config=crypto-config.yaml --output=crypto-config
  "

  local required_crypto=(
    "$NETWORK_DIR/crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/msp/signcerts/orderer.evidentia.network-cert.pem"
    "$NETWORK_DIR/crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/tls/server.crt"
    "$NETWORK_DIR/crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/tls/server.key"
    "$NETWORK_DIR/crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/tls/ca.crt"
  )
  for file in "${required_crypto[@]}"; do
    [[ -f "$file" ]] || { printError "Missing required crypto artifact: $file"; exit 1; }
  done

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

    configtxgen -profile '$SYSTEM_PROFILE' -channelID system-channel -outputBlock ./channel-artifacts/genesis.block
    configtxgen -profile '$CHANNEL_PROFILE' -channelID '$CHANNEL_NAME' -outputCreateChannelTx ./channel-artifacts/channel.tx
    configtxgen -profile '$CHANNEL_PROFILE' -channelID '$CHANNEL_NAME' -outputBlock ./channel-artifacts/$CHANNEL_BLOCK_FILE

    configtxgen -profile '$CHANNEL_PROFILE' -channelID '$CHANNEL_NAME' -asOrg LawEnforcementOrg -outputAnchorPeersUpdate ./channel-artifacts/LawEnforcementMSPanchors.tx
    configtxgen -profile '$CHANNEL_PROFILE' -channelID '$CHANNEL_NAME' -asOrg ForensicLabOrg -outputAnchorPeersUpdate ./channel-artifacts/ForensicLabMSPanchors.tx
    configtxgen -profile '$CHANNEL_PROFILE' -channelID '$CHANNEL_NAME' -asOrg JudiciaryOrg -outputAnchorPeersUpdate ./channel-artifacts/JudiciaryMSPanchors.tx
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
    [[ -f "$artifact" ]] || { printError "Missing channel artifact: $artifact"; exit 1; }
  done

  printInfo "Channel artifacts generated successfully."
}

main() {
  printInfo "Starting Evidentia artifact generation..."
  checkPrereqs
  ensureCliContainer
  generateCryptoMaterials
  generateChannelArtifacts

  printInfo "======================================"
  printInfo "Crypto + channel artifact generation complete"
  printInfo "======================================"
  printInfo "Generated in: $NETWORK_DIR/crypto-config and $NETWORK_DIR/channel-artifacts"
  printInfo "Expected channel block: $NETWORK_DIR/channel-artifacts/$CHANNEL_BLOCK_FILE"
}

main "$@"
