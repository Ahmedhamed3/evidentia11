#!/usr/bin/env bash
set -euo pipefail

# Evidentia production-grade bootstrap orchestrator

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FABRIC_DIR="$PROJECT_ROOT/fabric-network"
FABRIC_DOCKER_DIR="$FABRIC_DIR/docker"
BACKEND_DIR="$PROJECT_ROOT/backend"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
RUNTIME_DIR="$PROJECT_ROOT/.runtime"
LOG_DIR="$RUNTIME_DIR/logs"
PID_DIR="$RUNTIME_DIR/pids"

CHANNEL_NAME="${CHANNEL_NAME:-evidence-channel}"
CHANNEL_PROFILE="${CHANNEL_PROFILE:-EvidentiaCoCChannel}"
SYSTEM_PROFILE="${SYSTEM_PROFILE:-OrdererGenesis}"
CHANNEL_BLOCK_FILE="${CHANNEL_NAME//-/}.block"
CHAINCODE_NAME="${CHAINCODE_NAME:-evidence-coc}"
CHAINCODE_VERSION="${CHAINCODE_VERSION:-1.0}"
CHAINCODE_SEQUENCE="${CHAINCODE_SEQUENCE:-1}"
BACKEND_PORT="${BACKEND_PORT:-3001}"
FRONTEND_PORT="${FRONTEND_PORT:-3000}"
IPFS_API_URL="${IPFS_API_URL:-http://localhost:5001/api/v0/version}"

RETRY_MAX="${RETRY_MAX:-40}"
RETRY_SLEEP="${RETRY_SLEEP:-3}"
GATEWAY_RETRY_MAX="${GATEWAY_RETRY_MAX:-20}"
GATEWAY_RETRY_SLEEP="${GATEWAY_RETRY_SLEEP:-3}"

# Optional override to force CCaaS deploy path when available.
CHAINCODE_DEPLOY_MODE="${CHAINCODE_DEPLOY_MODE:-auto}"  # auto|ccaas|legacy

CLI_CONTAINER_NAME="${CLI_CONTAINER_NAME:-cli}"
CLI_IMAGE="${CLI_IMAGE:-hyperledger/fabric-tools:2.5.10}"
CLI_NETWORK="${CLI_NETWORK:-evidentia_network}"
CLI_WORKDIR="/opt/gopath/src/github.com/hyperledger/fabric/peer"
CLI_CRYPTO_BASE="$CLI_WORKDIR/crypto-config"
CLI_ORDERER_CA="$CLI_CRYPTO_BASE/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/msp/tlscacerts/tlsca.evidentia.network-cert.pem"
CLI_ORDERER_ADMIN_CERT="$CLI_CRYPTO_BASE/ordererOrganizations/evidentia.network/users/Admin@evidentia.network/tls/client.crt"
CLI_ORDERER_ADMIN_KEY="$CLI_CRYPTO_BASE/ordererOrganizations/evidentia.network/users/Admin@evidentia.network/tls/client.key"
CLI_CHAINCODE_PATH="$CLI_WORKDIR/chaincode/${CHAINCODE_NAME}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CURRENT_STAGE="initialization"

mkdir -p "$LOG_DIR" "$PID_DIR"

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()  { echo -e "${BLUE}[STEP]${NC} $*"; }

on_error() {
  local exit_code="$1"
  log_error "Failure in stage: ${CURRENT_STAGE}"
  log_error "Exit code: ${exit_code}"
  exit "$exit_code"
}
trap 'on_error $?' ERR

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log_error "Required command not found: $1"
    exit 1
  }
}

run_compose() {
  docker compose "$@"
}

is_wsl() {
  grep -qiE "microsoft|wsl" /proc/version 2>/dev/null
}

detect_os() {
  CURRENT_STAGE="OS detection"
  case "$(uname -s)" in
    Linux)
      if is_wsl; then
        echo "WSL"
      else
        echo "Linux"
      fi
      ;;
    Darwin)
      echo "macOS"
      ;;
    *)
      echo "Unknown"
      ;;
  esac
}

normalize_docker_api_env() {
  if [[ -n "${DOCKER_API_VERSION:-}" ]]; then
    log_warn "Detected DOCKER_API_VERSION=${DOCKER_API_VERSION} in host shell; unsetting to allow Docker API negotiation."
    unset DOCKER_API_VERSION
  fi
}

verify_prereqs() {
  CURRENT_STAGE="prerequisite validation"
  require_cmd docker
  require_cmd curl
  require_cmd jq
  require_cmd node
  require_cmd npm

  if ! docker compose version >/dev/null 2>&1; then
    log_error "Docker Compose v2 is required (docker compose)."
    exit 1
  fi

  normalize_docker_api_env
  verify_docker_daemon
}

verify_docker_daemon() {
  CURRENT_STAGE="docker daemon verification"
  if ! docker info >/dev/null 2>&1; then
    log_error "Docker daemon is not running. Start Docker and retry."
    exit 1
  fi
  log_info "Docker daemon is healthy."
}

container_running() {
  docker ps --format '{{.Names}}' | grep -Fxq "$1"
}

container_exists() {
  docker ps -a --format '{{.Names}}' | grep -Fxq "$1"
}

wait_until() {
  local description="$1"
  local max_retries="$2"
  local sleep_seconds="$3"
  local cmd="$4"

  local attempt=1
  while (( attempt <= max_retries )); do
    if bash -c "$cmd" >/dev/null 2>&1; then
      log_info "$description (ready after attempt $attempt/$max_retries)"
      return 0
    fi
    sleep "$sleep_seconds"
    ((attempt++))
  done

  log_error "Timed out waiting for: $description"
  return 1
}

# Execute a command in the Fabric CLI container.
cli_exec() {
  docker exec "$CLI_CONTAINER_NAME" bash -lc "$*"
}

# Write command output from CLI container to stdout (without failing set -e pipeline usage).
cli_exec_capture() {
  docker exec "$CLI_CONTAINER_NAME" bash -lc "$*"
}

sync_path_to_cli() {
  local source_path="$1"
  local target_path="$2"

  if [[ ! -e "$source_path" ]]; then
    return 0
  fi

  if docker inspect "$CLI_CONTAINER_NAME" --format '{{json .Mounts}}' 2>/dev/null \
    | jq -e --arg target "$target_path" '.[] | select(.Destination == $target)' >/dev/null 2>&1; then
    log_info "Skipping docker cp for mounted CLI path: ${target_path}"
    return 0
  fi

  cli_exec "mkdir -p '$(dirname "$target_path")' && rm -rf '$target_path'"
  docker cp "$source_path" "${CLI_CONTAINER_NAME}:${target_path}"
}

sync_cli_workspace() {
  CURRENT_STAGE="fabric CLI workspace synchronization"

  mkdir -p "$FABRIC_DIR/crypto-config" "$FABRIC_DIR/channel-artifacts"

  sync_path_to_cli "$FABRIC_DIR/crypto-config" "$CLI_CRYPTO_BASE"
  sync_path_to_cli "$FABRIC_DIR/channel-artifacts" "$CLI_WORKDIR/channel-artifacts"
  sync_path_to_cli "$PROJECT_ROOT/chaincode" "$CLI_WORKDIR/chaincode"
  sync_path_to_cli "$FABRIC_DIR/scripts" "$CLI_WORKDIR/scripts"

  if [[ -f "$FABRIC_DIR/configtx.yaml" ]]; then
    docker cp "$FABRIC_DIR/configtx.yaml" "${CLI_CONTAINER_NAME}:${CLI_WORKDIR}/configtx.yaml"
  fi
  if [[ -f "$FABRIC_DIR/crypto-config.yaml" ]]; then
    docker cp "$FABRIC_DIR/crypto-config.yaml" "${CLI_CONTAINER_NAME}:${CLI_WORKDIR}/crypto-config.yaml"
  fi
  if [[ -f "$FABRIC_DIR/collections_config.json" ]]; then
    docker cp "$FABRIC_DIR/collections_config.json" "${CLI_CONTAINER_NAME}:${CLI_WORKDIR}/collections_config.json"
  fi
}

fabric_peer_env() {
  local org="$1"
  case "$org" in
    LawEnforcement)
      cat <<EOF_ENV
export CORE_PEER_LOCALMSPID=LawEnforcementMSP
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_ADDRESS=peer0.lawenforcement.evidentia.network:7051
export CORE_PEER_TLS_ROOTCERT_FILE=${CLI_CRYPTO_BASE}/peerOrganizations/lawenforcement.evidentia.network/peers/peer0.lawenforcement.evidentia.network/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${CLI_CRYPTO_BASE}/peerOrganizations/lawenforcement.evidentia.network/users/Admin@lawenforcement.evidentia.network/msp
EOF_ENV
      ;;
    ForensicLab)
      cat <<EOF_ENV
export CORE_PEER_LOCALMSPID=ForensicLabMSP
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_ADDRESS=peer0.forensiclab.evidentia.network:9051
export CORE_PEER_TLS_ROOTCERT_FILE=${CLI_CRYPTO_BASE}/peerOrganizations/forensiclab.evidentia.network/peers/peer0.forensiclab.evidentia.network/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${CLI_CRYPTO_BASE}/peerOrganizations/forensiclab.evidentia.network/users/Admin@forensiclab.evidentia.network/msp
EOF_ENV
      ;;
    Judiciary)
      cat <<EOF_ENV
export CORE_PEER_LOCALMSPID=JudiciaryMSP
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_ADDRESS=peer0.judiciary.evidentia.network:11051
export CORE_PEER_TLS_ROOTCERT_FILE=${CLI_CRYPTO_BASE}/peerOrganizations/judiciary.evidentia.network/peers/peer0.judiciary.evidentia.network/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${CLI_CRYPTO_BASE}/peerOrganizations/judiciary.evidentia.network/users/Admin@judiciary.evidentia.network/msp
EOF_ENV
      ;;
    *)
      log_error "Unknown org requested for peer env: $org"
      exit 1
      ;;
  esac
}

with_peer_env() {
  local org="$1"
  local cmd="$2"
  local env_block
  env_block="$(fabric_peer_env "$org")"
  cli_exec "${env_block}; ${cmd}"
}

ensure_cli_container() {
  CURRENT_STAGE="fabric CLI container readiness"

  if container_running "$CLI_CONTAINER_NAME"; then
    log_info "Fabric CLI container '${CLI_CONTAINER_NAME}' is already running."
    sync_cli_workspace
    return 0
  fi

  if container_exists "$CLI_CONTAINER_NAME"; then
    log_step "Starting existing Fabric CLI container '${CLI_CONTAINER_NAME}'"
    docker start "$CLI_CONTAINER_NAME" >/dev/null
    wait_until "CLI container ${CLI_CONTAINER_NAME} running" "$RETRY_MAX" "$RETRY_SLEEP" "docker ps --format '{{.Names}}' | grep -Fxq '${CLI_CONTAINER_NAME}'"
    sync_cli_workspace
    return 0
  fi

  if [[ -f "$FABRIC_DOCKER_DIR/docker-compose-fabric.yaml" ]]; then
    log_step "Creating Fabric CLI container '${CLI_CONTAINER_NAME}' via docker compose"
    (cd "$FABRIC_DOCKER_DIR" && run_compose -f docker-compose-fabric.yaml up -d --no-deps "$CLI_CONTAINER_NAME")
  else
    log_step "Creating Fabric CLI container '${CLI_CONTAINER_NAME}' via docker run"
    docker run -d --name "$CLI_CONTAINER_NAME" --network "$CLI_NETWORK" -w "$CLI_WORKDIR" "$CLI_IMAGE" /bin/bash -lc "trap : TERM INT; sleep infinity & wait"
  fi

  wait_until "CLI container ${CLI_CONTAINER_NAME} running" "$RETRY_MAX" "$RETRY_SLEEP" "docker ps --format '{{.Names}}' | grep -Fxq '${CLI_CONTAINER_NAME}'"
  sync_cli_workspace
}

ensure_crypto_material() {
  CURRENT_STAGE="crypto material verification"

  local required_artifacts=(
    "$FABRIC_DIR/channel-artifacts/genesis.block"
    "$FABRIC_DIR/channel-artifacts/channel.tx"
    "$FABRIC_DIR/channel-artifacts/$CHANNEL_BLOCK_FILE"
    "$FABRIC_DIR/channel-artifacts/LawEnforcementMSPanchors.tx"
    "$FABRIC_DIR/channel-artifacts/ForensicLabMSPanchors.tx"
    "$FABRIC_DIR/channel-artifacts/JudiciaryMSPanchors.tx"
  )

  if [[ -d "$FABRIC_DIR/crypto-config" ]]; then
    local all_present=true
    for artifact in "${required_artifacts[@]}"; do
      [[ -f "$artifact" ]] || { all_present=false; break; }
    done
    if [[ "$all_present" == "true" ]]; then
      log_info "Crypto materials and all channel artifacts already exist."
      return 0
    fi
  fi

  log_step "Generating crypto material and channel artifacts (Dockerized fabric-tools)"
  rm -rf "$FABRIC_DIR/crypto-config" "$FABRIC_DIR/channel-artifacts"
  mkdir -p "$FABRIC_DIR/crypto-config" "$FABRIC_DIR/channel-artifacts"

  ensure_cli_container
  sync_cli_workspace

  cli_exec "
    cd '${CLI_WORKDIR}'
    export FABRIC_CFG_PATH='${CLI_WORKDIR}'
    rm -rf ./crypto/* ./channel-artifacts/*

    cryptogen generate --config=crypto-config.yaml --output=crypto-config

    # Generate required artifacts for both legacy workflows and osnadmin channel participation.
    configtxgen -profile '${SYSTEM_PROFILE}' -channelID system-channel -outputBlock ./channel-artifacts/genesis.block
    configtxgen -profile '${CHANNEL_PROFILE}' -channelID '${CHANNEL_NAME}' -outputCreateChannelTx ./channel-artifacts/channel.tx
    configtxgen -profile '${CHANNEL_PROFILE}' -channelID '${CHANNEL_NAME}' -outputBlock ./channel-artifacts/${CHANNEL_BLOCK_FILE}

    configtxgen -profile '${CHANNEL_PROFILE}' -channelID '${CHANNEL_NAME}' -asOrg LawEnforcementOrg -outputAnchorPeersUpdate ./channel-artifacts/LawEnforcementMSPanchors.tx
    configtxgen -profile '${CHANNEL_PROFILE}' -channelID '${CHANNEL_NAME}' -asOrg ForensicLabOrg -outputAnchorPeersUpdate ./channel-artifacts/ForensicLabMSPanchors.tx
    configtxgen -profile '${CHANNEL_PROFILE}' -channelID '${CHANNEL_NAME}' -asOrg JudiciaryOrg -outputAnchorPeersUpdate ./channel-artifacts/JudiciaryMSPanchors.tx

    cp crypto-config/ordererOrganizations/evidentia.network/users/Admin@evidentia.network/msp/signcerts/Admin@evidentia.network-cert.pem crypto-config/ordererOrganizations/evidentia.network/msp/admincerts/ 2>/dev/null || true
  "

  for artifact in "${required_artifacts[@]}"; do
    [[ -f "$artifact" ]] || { log_error "Expected channel artifact missing after generation: $artifact"; exit 1; }
  done

  log_info "Crypto material and channel artifacts generated via Docker container."
}
start_fabric_network_if_needed() {
  CURRENT_STAGE="fabric network startup"
  local required=(
    orderer.evidentia.network
    peer0.lawenforcement.evidentia.network
    peer0.forensiclab.evidentia.network
    peer0.judiciary.evidentia.network
    couchdb.lawenforcement
    couchdb.forensiclab
    couchdb.judiciary
    ipfs.evidentia.network
    "$CLI_CONTAINER_NAME"
  )

  local all_running=true
  for c in "${required[@]}"; do
    if ! container_running "$c"; then
      all_running=false
      break
    fi
  done

  if [[ "$all_running" == "true" ]]; then
    log_info "Fabric + CouchDB + IPFS + CLI containers are already running."
    return 0
  fi

  log_step "Starting CouchDB, Fabric, and IPFS containers"
  (cd "$FABRIC_DOCKER_DIR" && run_compose -f docker-compose-couch.yaml up -d)
  (cd "$FABRIC_DOCKER_DIR" && run_compose -f docker-compose-fabric.yaml up -d)
  (cd "$FABRIC_DOCKER_DIR" && run_compose -f docker-compose-ipfs.yaml up -d)

  verify_required_containers
  ensure_cli_container
}

verify_required_containers() {
  CURRENT_STAGE="required container verification"
  local required=(
    orderer.evidentia.network
    peer0.lawenforcement.evidentia.network
    peer0.forensiclab.evidentia.network
    peer0.judiciary.evidentia.network
    couchdb.lawenforcement
    couchdb.forensiclab
    couchdb.judiciary
    ipfs.evidentia.network
    "$CLI_CONTAINER_NAME"
  )

  for c in "${required[@]}"; do
    wait_until "container $c running" "$RETRY_MAX" "$RETRY_SLEEP" "docker ps --format '{{.Names}}' | grep -Fxq '$c'"
  done
}

channel_exists() {
  CURRENT_STAGE="channel existence check"
  ensure_cli_container

  cli_exec "
    osnadmin channel list -o orderer.evidentia.network:7053 \
      --ca-file '${CLI_ORDERER_CA}' \
      --client-cert '${CLI_ORDERER_ADMIN_CERT}' \
      --client-key '${CLI_ORDERER_ADMIN_KEY}' 2>/dev/null | grep -q '\"name\": \"${CHANNEL_NAME}\"'
  "
}

join_channel_for_org() {
  local org="$1"
  local join_cmd="peer channel join -b ${CLI_WORKDIR}/channel-artifacts/${CHANNEL_BLOCK_FILE}"

  log_info "Joining ${org} peer to channel '${CHANNEL_NAME}'"
  local attempt=1
  while (( attempt <= RETRY_MAX )); do
    if with_peer_env "$org" "$join_cmd" >/dev/null 2>&1; then
      log_info "${org} joined '${CHANNEL_NAME}'."
      return 0
    fi
    log_warn "Join failed for ${org}, retrying (${attempt}/${RETRY_MAX})"
    sleep "$RETRY_SLEEP"
    ((attempt++))
  done

  log_error "Failed to join ${org} peer to channel '${CHANNEL_NAME}'."
  exit 1
}

verify_channel_artifacts_for_osnadmin() {
  local required=(
    "${FABRIC_DIR}/channel-artifacts/genesis.block"
    "${FABRIC_DIR}/channel-artifacts/channel.tx"
    "${FABRIC_DIR}/channel-artifacts/${CHANNEL_BLOCK_FILE}"
    "${FABRIC_DIR}/channel-artifacts/LawEnforcementMSPanchors.tx"
    "${FABRIC_DIR}/channel-artifacts/ForensicLabMSPanchors.tx"
    "${FABRIC_DIR}/channel-artifacts/JudiciaryMSPanchors.tx"
    "${FABRIC_DIR}/crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/tls/ca.crt"
    "${FABRIC_DIR}/crypto-config/ordererOrganizations/evidentia.network/users/Admin@evidentia.network/tls/client.crt"
    "${FABRIC_DIR}/crypto-config/ordererOrganizations/evidentia.network/users/Admin@evidentia.network/tls/client.key"
  )

  local missing=0
  for path in "${required[@]}"; do
    if [[ ! -f "$path" ]]; then
      log_error "Required file missing: $path"
      missing=1
    fi
  done

  if (( missing == 1 )); then
    log_error "Regenerate artifacts with: ./fabric-network/scripts/generate.sh"
    exit 1
  fi
}

submit_anchor_update_for_org() {
  local org="$1"
  local anchor_file="$2"

  if [[ ! -f "${FABRIC_DIR}/channel-artifacts/${anchor_file}" ]]; then
    log_error "Missing anchor peer update transaction: ${FABRIC_DIR}/channel-artifacts/${anchor_file}"
    exit 1
  fi

  log_info "Submitting anchor peer update for ${org}"
  with_peer_env "$org" "peer channel update -o orderer.evidentia.network:7050 --ordererTLSHostnameOverride orderer.evidentia.network -c '${CHANNEL_NAME}' -f '${CLI_WORKDIR}/channel-artifacts/${anchor_file}' --tls --cafile '${CLI_ORDERER_CA}'"
}

verify_anchor_peers_in_channel_block() {
  CURRENT_STAGE="anchor peer validation"

  local channel_block="${CLI_WORKDIR}/channel-artifacts/${CHANNEL_BLOCK_FILE}"
  local inspect_file="${CLI_WORKDIR}/channel-artifacts/${CHANNEL_BLOCK_FILE}.json"

  cli_exec "
    cd '${CLI_WORKDIR}'
    configtxgen -inspectBlock '${channel_block}' > '${inspect_file}'
  "

  if ! cli_exec "jq -e '.data.data[0].payload.data.config.channel_group.groups.Application | type == \"object\"' '${inspect_file}' >/dev/null"; then
    log_error "Application group is missing in channel config block; cannot validate anchor peers."
    exit 1
  fi

  assert_anchor_peer_present() {
    local org_msp="$1"
    local expected_host="$2"
    local expected_port="$3"

    if ! cli_exec "jq -e --arg msp '${org_msp}' '
      (.data.data[0].payload.data.config.channel_group.groups.Application.groups // {})
      | to_entries
      | any((.value.values.MSP.value.config.name // empty) == \$msp)
    ' '${inspect_file}' >/dev/null"; then
      log_error "Org with MSP ID '${org_msp}' not found under Application in channel config block."
      exit 1
    fi

    if ! cli_exec "jq -e --arg msp '${org_msp}' --arg host '${expected_host}' --argjson port ${expected_port} '
      (
        (.data.data[0].payload.data.config.channel_group.groups.Application.groups // {})
        | to_entries[]?
        | select((.value.values.MSP.value.config.name // empty) == \$msp)
        | (.value.values.AnchorPeers.value.anchor_peers // [])
      )
      | any(.host == \$host and .port == \$port)
    ' '${inspect_file}' >/dev/null"; then
      log_error "Expected anchor peer ${expected_host}:${expected_port} not found for '${org_msp}'."
      exit 1
    fi
  }

  assert_anchor_peer_present "LawEnforcementMSP" "peer0.lawenforcement.evidentia.network" "7051"
  assert_anchor_peer_present "ForensicLabMSP" "peer0.forensiclab.evidentia.network" "9051"
  assert_anchor_peer_present "JudiciaryMSP" "peer0.judiciary.evidentia.network" "11051"

  log_info "Anchor peers are already embedded in the channel config block and active at channel creation time."
}

configure_anchor_peers() {
  CURRENT_STAGE="anchor peer configuration"

  # In channel participation mode (osnadmin/no system channel), this network embeds
  # anchor peer values directly in the application channel profile. Submitting separate
  # pre-generated anchor update tx files can fail with stale ReadSet versions.
  verify_anchor_peers_in_channel_block
}

ensure_channel() {
  CURRENT_STAGE="channel creation"
  ensure_cli_container
  verify_channel_artifacts_for_osnadmin

  if channel_exists; then
    log_info "Channel '${CHANNEL_NAME}' already exists."
  else
    log_step "Creating channel '${CHANNEL_NAME}' via CLI container"
    cli_exec "
      osnadmin channel join \
        --channelID '${CHANNEL_NAME}' \
        --config-block '${CLI_WORKDIR}/channel-artifacts/${CHANNEL_BLOCK_FILE}' \
        -o orderer.evidentia.network:7053 \
        --ca-file '${CLI_ORDERER_CA}' \
        --client-cert '${CLI_ORDERER_ADMIN_CERT}' \
        --client-key '${CLI_ORDERER_ADMIN_KEY}'
    "
    log_info "Channel '${CHANNEL_NAME}' created."
  fi

  join_channel_for_org "LawEnforcement"
  join_channel_for_org "ForensicLab"
  join_channel_for_org "Judiciary"

  configure_anchor_peers
}

query_installed_package_id() {
  with_peer_env "LawEnforcement" "peer lifecycle chaincode queryinstalled" \
    | awk -v label="${CHAINCODE_NAME}_${CHAINCODE_VERSION}" '$0 ~ label {gsub(/,$/, "", $3); print $3; exit}'
}

chaincode_committed() {
  with_peer_env "LawEnforcement" "peer lifecycle chaincode querycommitted -C '${CHANNEL_NAME}' -n '${CHAINCODE_NAME}'" 2>/dev/null \
    | grep -q "Version: ${CHAINCODE_VERSION}"
}

deploy_chaincode_legacy() {
  CURRENT_STAGE="chaincode deployment (legacy lifecycle via CLI container)"
  ensure_cli_container

  if chaincode_committed; then
    log_info "Chaincode '${CHAINCODE_NAME}' already committed on channel '${CHANNEL_NAME}'."
    return 0
  fi

  log_step "Packaging and installing chaincode (${CHAINCODE_NAME}) in CLI container"
  cli_exec "
    rm -f '${CLI_WORKDIR}/${CHAINCODE_NAME}.tar.gz'
    cd '${CLI_CHAINCODE_PATH}'
    GO111MODULE=on go mod tidy
    GO111MODULE=on go mod vendor
  "

  with_peer_env "LawEnforcement" "peer lifecycle chaincode package '${CLI_WORKDIR}/${CHAINCODE_NAME}.tar.gz' --path '${CLI_CHAINCODE_PATH}' --lang golang --label '${CHAINCODE_NAME}_${CHAINCODE_VERSION}'"

  with_peer_env "LawEnforcement" "peer lifecycle chaincode install '${CLI_WORKDIR}/${CHAINCODE_NAME}.tar.gz'"
  with_peer_env "ForensicLab" "peer lifecycle chaincode install '${CLI_WORKDIR}/${CHAINCODE_NAME}.tar.gz'"
  with_peer_env "Judiciary" "peer lifecycle chaincode install '${CLI_WORKDIR}/${CHAINCODE_NAME}.tar.gz'"

  local package_id
  package_id="$(query_installed_package_id)"
  if [[ -z "$package_id" ]]; then
    log_error "Could not determine package ID for ${CHAINCODE_NAME}_${CHAINCODE_VERSION}"
    exit 1
  fi
  log_info "Package ID resolved: ${package_id}"

  local cc_collections="${CLI_WORKDIR}/collections_config.json"

  with_peer_env "LawEnforcement" "peer lifecycle chaincode approveformyorg -o orderer.evidentia.network:7050 --ordererTLSHostnameOverride orderer.evidentia.network --channelID '${CHANNEL_NAME}' --name '${CHAINCODE_NAME}' --version '${CHAINCODE_VERSION}' --package-id '${package_id}' --sequence '${CHAINCODE_SEQUENCE}' --tls --cafile '${CLI_ORDERER_CA}' --collections-config '${cc_collections}'"
  with_peer_env "ForensicLab" "peer lifecycle chaincode approveformyorg -o orderer.evidentia.network:7050 --ordererTLSHostnameOverride orderer.evidentia.network --channelID '${CHANNEL_NAME}' --name '${CHAINCODE_NAME}' --version '${CHAINCODE_VERSION}' --package-id '${package_id}' --sequence '${CHAINCODE_SEQUENCE}' --tls --cafile '${CLI_ORDERER_CA}' --collections-config '${cc_collections}'"
  with_peer_env "Judiciary" "peer lifecycle chaincode approveformyorg -o orderer.evidentia.network:7050 --ordererTLSHostnameOverride orderer.evidentia.network --channelID '${CHANNEL_NAME}' --name '${CHAINCODE_NAME}' --version '${CHAINCODE_VERSION}' --package-id '${package_id}' --sequence '${CHAINCODE_SEQUENCE}' --tls --cafile '${CLI_ORDERER_CA}' --collections-config '${cc_collections}'"

  log_step "Committing chaincode definition"
  with_peer_env "LawEnforcement" "peer lifecycle chaincode commit -o orderer.evidentia.network:7050 --ordererTLSHostnameOverride orderer.evidentia.network --channelID '${CHANNEL_NAME}' --name '${CHAINCODE_NAME}' --version '${CHAINCODE_VERSION}' --sequence '${CHAINCODE_SEQUENCE}' --tls --cafile '${CLI_ORDERER_CA}' --peerAddresses peer0.lawenforcement.evidentia.network:7051 --tlsRootCertFiles '${CLI_CRYPTO_BASE}/peerOrganizations/lawenforcement.evidentia.network/peers/peer0.lawenforcement.evidentia.network/tls/ca.crt' --peerAddresses peer0.forensiclab.evidentia.network:9051 --tlsRootCertFiles '${CLI_CRYPTO_BASE}/peerOrganizations/forensiclab.evidentia.network/peers/peer0.forensiclab.evidentia.network/tls/ca.crt' --peerAddresses peer0.judiciary.evidentia.network:11051 --tlsRootCertFiles '${CLI_CRYPTO_BASE}/peerOrganizations/judiciary.evidentia.network/peers/peer0.judiciary.evidentia.network/tls/ca.crt' --collections-config '${cc_collections}'"

  with_peer_env "LawEnforcement" "peer lifecycle chaincode querycommitted -C '${CHANNEL_NAME}' -n '${CHAINCODE_NAME}'"
}

deploy_chaincode_ccaas() {
  CURRENT_STAGE="chaincode deployment (CCaaS script via CLI container)"
  ensure_cli_container
  log_step "Running CCaaS deployment script inside CLI container"
  cli_exec "cd '${CLI_WORKDIR}' && ./scripts/deploy-chaincode-ccaas.sh"
}

deploy_chaincode() {
  if chaincode_committed; then
    log_info "Chaincode '${CHAINCODE_NAME}' already committed on channel '${CHANNEL_NAME}'."
    return 0
  fi

  case "$CHAINCODE_DEPLOY_MODE" in
    ccaas)
      deploy_chaincode_ccaas
      ;;
    legacy)
      deploy_chaincode_legacy
      ;;
    auto|*)
      if cli_exec "test -x '${CLI_WORKDIR}/scripts/deploy-chaincode-ccaas.sh'" >/dev/null 2>&1; then
        if ! deploy_chaincode_ccaas; then
          log_warn "CCaaS deploy path failed; falling back to legacy lifecycle deployment."
          deploy_chaincode_legacy
        fi
      else
        deploy_chaincode_legacy
      fi
      ;;
  esac
}

verify_chaincode_runtime() {
  CURRENT_STAGE="chaincode runtime verification"

  wait_until "chaincode committed on channel" "$RETRY_MAX" "$RETRY_SLEEP" "docker exec ${CLI_CONTAINER_NAME} bash -lc \"$(fabric_peer_env LawEnforcement); peer lifecycle chaincode querycommitted -C '${CHANNEL_NAME}' -n '${CHAINCODE_NAME}' | grep -q 'Version: ${CHAINCODE_VERSION}'\""

  wait_until "chaincode container process" "$RETRY_MAX" "$RETRY_SLEEP" "docker ps --format '{{.Names}}' | grep -E '(${CHAINCODE_NAME}|dev-peer.*${CHAINCODE_NAME})'"
}

ensure_backend_env() {
  if [[ ! -f "$BACKEND_DIR/.env" ]]; then
    cp "$BACKEND_DIR/env.example" "$BACKEND_DIR/.env"
    log_warn "Created backend/.env from env.example; adjust secrets for production deployments."
  fi
}

is_port_open() {
  local port="$1"
  if command -v nc >/dev/null 2>&1; then
    nc -z localhost "$port"
  else
    (echo >"/dev/tcp/localhost/$port") >/dev/null 2>&1
  fi
}

start_backend() {
  CURRENT_STAGE="backend startup"
  ensure_backend_env

  if curl -fsS "http://localhost:${BACKEND_PORT}/health" >/dev/null 2>&1; then
    log_info "Backend already healthy on port ${BACKEND_PORT}."
    return 0
  fi

  if [[ -f "$PID_DIR/backend.pid" ]]; then
    local existing_pid
    existing_pid="$(cat "$PID_DIR/backend.pid")"
    if ps -p "$existing_pid" >/dev/null 2>&1; then
      log_warn "Found backend PID ${existing_pid}; waiting for health before restart."
      if wait_until "backend health endpoint" "$GATEWAY_RETRY_MAX" "$GATEWAY_RETRY_SLEEP" "curl -fsS http://localhost:${BACKEND_PORT}/health"; then
        return 0
      fi
      kill "$existing_pid" || true
    fi
    rm -f "$PID_DIR/backend.pid"
  fi

  log_step "Starting backend (npm run dev)"
  (cd "$BACKEND_DIR" && nohup npm run dev >"$LOG_DIR/backend.log" 2>&1 & echo $! >"$PID_DIR/backend.pid")

  wait_until "backend health endpoint" "$GATEWAY_RETRY_MAX" "$GATEWAY_RETRY_SLEEP" "curl -fsS http://localhost:${BACKEND_PORT}/health"
}

start_frontend() {
  CURRENT_STAGE="frontend startup"

  if is_port_open "$FRONTEND_PORT"; then
    log_info "Frontend already responding on port ${FRONTEND_PORT}."
    return 0
  fi

  if [[ -f "$PID_DIR/frontend.pid" ]]; then
    local existing_pid
    existing_pid="$(cat "$PID_DIR/frontend.pid")"
    if ps -p "$existing_pid" >/dev/null 2>&1; then
      log_warn "Found frontend PID ${existing_pid}; waiting for port readiness before restart."
      if wait_until "frontend port ${FRONTEND_PORT}" "$RETRY_MAX" "$RETRY_SLEEP" "bash -lc '$(declare -f is_port_open); is_port_open ${FRONTEND_PORT}'"; then
        return 0
      fi
      kill "$existing_pid" || true
    fi
    rm -f "$PID_DIR/frontend.pid"
  fi

  log_step "Starting frontend (npm start)"
  (cd "$FRONTEND_DIR" && nohup npm start >"$LOG_DIR/frontend.log" 2>&1 & echo $! >"$PID_DIR/frontend.pid")

  wait_until "frontend port ${FRONTEND_PORT}" "$RETRY_MAX" "$RETRY_SLEEP" "bash -lc '$(declare -f is_port_open); is_port_open ${FRONTEND_PORT}'"
}

stop_app_if_running() {
  local name="$1"
  local pid_file="$PID_DIR/${name}.pid"

  if [[ -f "$pid_file" ]]; then
    local pid
    pid="$(cat "$pid_file")"
    if ps -p "$pid" >/dev/null 2>&1; then
      log_info "Stopping ${name} process PID ${pid}"
      kill "$pid" || true
      wait_until "${name} PID ${pid} stopped" 10 1 "! ps -p ${pid} >/dev/null 2>&1"
    fi
    rm -f "$pid_file"
  fi
}

full_test_sequence() {
  CURRENT_STAGE="post-start test sequence"
  ensure_cli_container
  log_step "Running full validation sequence"

  # A) docker ps validation
  log_info "A) Validating expected containers"
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | tee "$LOG_DIR/docker-ps.txt"

  local expected=(
    orderer.evidentia.network
    peer0.lawenforcement.evidentia.network
    peer0.forensiclab.evidentia.network
    peer0.judiciary.evidentia.network
    couchdb.lawenforcement
    couchdb.forensiclab
    couchdb.judiciary
    ipfs.evidentia.network
    "$CLI_CONTAINER_NAME"
  )
  for c in "${expected[@]}"; do
    container_running "$c" || { log_error "Test failure at stage A: missing container ${c}"; exit 1; }
  done

  # B) backend health endpoint
  log_info "B) Checking backend health endpoint"
  local health_json
  health_json="$(curl -fsS "http://localhost:${BACKEND_PORT}/health")"
  echo "$health_json" | jq . >/dev/null

  # C) submit sample Fabric transaction using backend API
  log_info "C) Submitting sample Fabric transaction via backend API"
  local token evidence_id tx_payload
  token="$(curl -fsS -X POST "http://localhost:${BACKEND_PORT}/api/auth/login" \
    -H 'Content-Type: application/json' \
    -d '{"username":"admin","password":"admin123"}' | jq -r '.data.token')"
  [[ -n "$token" && "$token" != "null" ]] || { log_error "Test failure at stage C: failed to obtain auth token"; exit 1; }

  evidence_id="EVD-RUN-$(date +%s)"
  tx_payload="$(jq -n --arg eid "$evidence_id" '{evidenceId:$eid,caseId:"CASE-RUN-001",ipfsHash:"QmRunScriptDeterministicCID000000000000000000001",evidenceHash:"a3f5d8bc9a2e7b3c4d5e6f7081920abcdeffedcba0123456789abcdef123456",encryptionKeyId:"key-run-script",metadata:{name:"run.sh synthetic evidence",type:"DIGITAL",sourceDevice:"CI",location:"Lab-A",notes:"automated bootstrap test"}}')"

  curl -fsS -X POST "http://localhost:${BACKEND_PORT}/api/forensic/ingest" \
    -H 'Content-Type: application/json' \
    -H 'x-api-key: demo-tool-key' \
    -d "$tx_payload" >/dev/null || { log_error "Test failure at stage C: transaction submission failed"; exit 1; }

  # D) query ledger state to verify transaction committed through backend
  log_info "D) Querying ledger state through backend"
  local query_json
  query_json="$(curl -fsS "http://localhost:${BACKEND_PORT}/api/forensic/evidence/${evidence_id}" -H 'x-api-key: demo-tool-key')"
  echo "$query_json" | jq -e '.success == true and .data.evidenceId != null' >/dev/null || { log_error "Test failure at stage D: evidence query failed"; exit 1; }

  # E) invoke/query ledger directly using peer CLI inside docker container
  log_info "E) Verifying ledger directly from CLI container"
  with_peer_env "LawEnforcement" "peer chaincode query -C '${CHANNEL_NAME}' -n '${CHAINCODE_NAME}' -c '{\"function\":\"GetEvidence\",\"Args\":[\"${evidence_id}\"]}'" \
    | tee "$LOG_DIR/chaincode-query.txt" \
    | grep -q "$evidence_id" || { log_error "Test failure at stage E: chaincode query did not return expected evidence"; exit 1; }

  # F) IPFS version endpoint
  log_info "F) Querying IPFS version endpoint"
  local ipfs_json
  ipfs_json="$(curl -fsS "$IPFS_API_URL")"
  echo "$ipfs_json" | jq . >/dev/null || { log_error "Test failure at stage F: IPFS API not responding"; exit 1; }

  # G)
  log_info "G) SUCCESS: all startup and validation checks passed."
}

start_flow() {
  CURRENT_STAGE="start flow"
  log_step "Executing START mode"

  verify_prereqs
  local os_name
  os_name="$(detect_os)"
  log_info "Detected OS: ${os_name}"

  ensure_crypto_material
  start_fabric_network_if_needed
  verify_required_containers
  ensure_cli_container
  ensure_channel
  deploy_chaincode
  verify_chaincode_runtime

  start_backend
  start_frontend

  full_test_sequence
}

stop_network_destructive() {
  CURRENT_STAGE="network teardown"
  log_step "Stopping and removing Fabric + CouchDB + IPFS resources"

  (cd "$FABRIC_DOCKER_DIR" && run_compose -f docker-compose-ipfs.yaml down --volumes --remove-orphans || true)
  (cd "$FABRIC_DOCKER_DIR" && run_compose -f docker-compose-fabric.yaml down --volumes --remove-orphans || true)
  (cd "$FABRIC_DOCKER_DIR" && run_compose -f docker-compose-couch.yaml down --volumes --remove-orphans || true)

  docker rm -f $(docker ps -aq --filter "name=dev-peer") >/dev/null 2>&1 || true
  docker rm -f $(docker ps -aq --filter "name=${CHAINCODE_NAME}") >/dev/null 2>&1 || true

  docker volume prune -f >/dev/null 2>&1 || true
}

reset_flow() {
  CURRENT_STAGE="reset flow"
  log_step "Executing RESET mode (destructive)"

  verify_prereqs
  stop_app_if_running backend
  stop_app_if_running frontend
  stop_network_destructive

  CURRENT_STAGE="artifact regeneration"
  rm -rf "$FABRIC_DIR/crypto-config" "$FABRIC_DIR/channel-artifacts" "$FABRIC_DIR/${CHAINCODE_NAME}.tar.gz" "$FABRIC_DIR/ccaas-package"

  ensure_crypto_material
  start_fabric_network_if_needed
  verify_required_containers
  ensure_cli_container
  ensure_channel
  deploy_chaincode
  verify_chaincode_runtime
  start_backend
  start_frontend
  full_test_sequence
}

restart_flow() {
  CURRENT_STAGE="restart flow"
  log_step "Executing RESTART mode"

  verify_prereqs
  stop_app_if_running backend
  stop_app_if_running frontend
  stop_network_destructive
  start_flow
}

status_flow() {
  CURRENT_STAGE="status flow"
  log_step "Evidentia stack status"

  if docker info >/dev/null 2>&1; then
    log_info "Docker daemon: RUNNING"
  else
    log_warn "Docker daemon: NOT RUNNING"
  fi

  echo
  log_info "Fabric/CouchDB/IPFS/CLI containers:"
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | awk 'NR==1 || /orderer\.evidentia\.network|peer0\.|couchdb\.|ipfs\.evidentia\.network|^cli/'

  echo
  if docker ps --format '{{.Names}}' | grep -E "(${CHAINCODE_NAME}|dev-peer.*${CHAINCODE_NAME})" >/dev/null 2>&1; then
    log_info "Chaincode container: RUNNING"
  else
    log_warn "Chaincode container: NOT DETECTED"
  fi

  echo
  if curl -fsS "http://localhost:${BACKEND_PORT}/health" >/dev/null 2>&1; then
    log_info "Backend health: HEALTHY"
  else
    log_warn "Backend health: UNREACHABLE"
  fi

  if is_port_open "$FRONTEND_PORT"; then
    log_info "Frontend port ${FRONTEND_PORT}: OPEN"
  else
    log_warn "Frontend port ${FRONTEND_PORT}: CLOSED"
  fi

  if curl -fsS "$IPFS_API_URL" >/dev/null 2>&1; then
    log_info "IPFS endpoint: HEALTHY"
  else
    log_warn "IPFS endpoint: UNREACHABLE"
  fi

  if container_running "$CLI_CONTAINER_NAME"; then
    log_info "CLI container (${CLI_CONTAINER_NAME}): RUNNING"
  else
    log_warn "CLI container (${CLI_CONTAINER_NAME}): NOT RUNNING"
  fi
}

print_usage() {
  cat <<USAGE
Usage: ./run.sh <mode>

Modes:
  start    Start full stack idempotently and run full test sequence
  restart  Restart full stack and run tests
  reset    Destructive reset (remove containers/volumes/artifacts), rebuild, and test
  status   Print stack component status
  test     Run full post-start validation sequence only
USAGE
}

main() {
  local mode="${1:-}"

  case "$mode" in
    start)
      start_flow
      ;;
    restart)
      restart_flow
      ;;
    reset)
      reset_flow
      ;;
    status)
      status_flow
      ;;
    test)
      verify_prereqs
      full_test_sequence
      ;;
    *)
      print_usage
      exit 1
      ;;
  esac
}

main "$@"
