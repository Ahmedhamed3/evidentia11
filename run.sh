#!/usr/bin/env bash
set -euo pipefail

# Evidentia production-grade bootstrap orchestrator

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FABRIC_DIR="$PROJECT_ROOT/fabric-network"
FABRIC_SCRIPTS_DIR="$FABRIC_DIR/scripts"
FABRIC_DOCKER_DIR="$FABRIC_DIR/docker"
BACKEND_DIR="$PROJECT_ROOT/backend"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
RUNTIME_DIR="$PROJECT_ROOT/.runtime"
LOG_DIR="$RUNTIME_DIR/logs"
PID_DIR="$RUNTIME_DIR/pids"

CHANNEL_NAME="${CHANNEL_NAME:-evidence-channel}"
CHAINCODE_NAME="${CHAINCODE_NAME:-evidence-coc}"
CHAINCODE_VERSION="${CHAINCODE_VERSION:-1.0}"
BACKEND_PORT="${BACKEND_PORT:-3001}"
FRONTEND_PORT="${FRONTEND_PORT:-3000}"
IPFS_API_URL="${IPFS_API_URL:-http://localhost:5001/api/v0/version}"

RETRY_MAX="${RETRY_MAX:-40}"
RETRY_SLEEP="${RETRY_SLEEP:-3}"
GATEWAY_RETRY_MAX="${GATEWAY_RETRY_MAX:-20}"
GATEWAY_RETRY_SLEEP="${GATEWAY_RETRY_SLEEP:-3}"

# Optional override to force CCaaS deploy path when available.
CHAINCODE_DEPLOY_MODE="${CHAINCODE_DEPLOY_MODE:-auto}"  # auto|ccaas|legacy

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

verify_prereqs() {
  CURRENT_STAGE="prerequisite validation"
  require_cmd docker
  require_cmd curl
  require_cmd jq
  require_cmd node
  require_cmd npm
  require_cmd peer
  require_cmd cryptogen
  require_cmd configtxgen
  require_cmd osnadmin

  if ! docker compose version >/dev/null 2>&1; then
    log_error "Docker Compose v2 is required (docker compose)."
    exit 1
  fi

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

ensure_crypto_material() {
  CURRENT_STAGE="crypto material verification"
  if [[ -d "$FABRIC_DIR/crypto-config" && -f "$FABRIC_DIR/channel-artifacts/evidencechannel.block" ]]; then
    log_info "Crypto materials and channel artifacts already exist."
    return 0
  fi

  log_step "Generating crypto material and channel artifacts"
  (cd "$FABRIC_DIR" && "$FABRIC_SCRIPTS_DIR/generate.sh")
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
  )

  local all_running=true
  for c in "${required[@]}"; do
    if ! container_running "$c"; then
      all_running=false
      break
    fi
  done

  if [[ "$all_running" == "true" ]]; then
    log_info "Fabric + CouchDB + IPFS containers are already running."
    return 0
  fi

  log_step "Starting CouchDB, Fabric, and IPFS containers"
  (cd "$FABRIC_DOCKER_DIR" && run_compose -f docker-compose-couch.yaml up -d)
  (cd "$FABRIC_DOCKER_DIR" && run_compose -f docker-compose-fabric.yaml up -d)
  (cd "$FABRIC_DOCKER_DIR" && run_compose -f docker-compose-ipfs.yaml up -d)

  verify_required_containers
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
  )

  for c in "${required[@]}"; do
    wait_until "container $c running" "$RETRY_MAX" "$RETRY_SLEEP" "docker ps --format '{{.Names}}' | grep -Fxq '$c'"
  done
}

fabric_env_law() {
  export CORE_PEER_LOCALMSPID="LawEnforcementMSP"
  export CORE_PEER_TLS_ENABLED=true
  export CORE_PEER_TLS_ROOTCERT_FILE="$FABRIC_DIR/crypto-config/peerOrganizations/lawenforcement.evidentia.network/peers/peer0.lawenforcement.evidentia.network/tls/ca.crt"
  export CORE_PEER_MSPCONFIGPATH="$FABRIC_DIR/crypto-config/peerOrganizations/lawenforcement.evidentia.network/users/Admin@lawenforcement.evidentia.network/msp"
  export CORE_PEER_ADDRESS="localhost:7051"
}

channel_exists() {
  CURRENT_STAGE="channel existence check"
  local orderer_tls_ca="$FABRIC_DIR/crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/msp/tlscacerts/tlsca.evidentia.network-cert.pem"
  local orderer_admin_cert="$FABRIC_DIR/crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/tls/server.crt"
  local orderer_admin_key="$FABRIC_DIR/crypto-config/ordererOrganizations/evidentia.network/orderers/orderer.evidentia.network/tls/server.key"

  osnadmin channel list -o localhost:7053 --ca-file "$orderer_tls_ca" --client-cert "$orderer_admin_cert" --client-key "$orderer_admin_key" 2>/dev/null \
    | grep -q "\"name\": \"${CHANNEL_NAME}\""
}

ensure_channel() {
  CURRENT_STAGE="channel creation"
  if channel_exists; then
    log_info "Channel '${CHANNEL_NAME}' already exists."
    return 0
  fi

  log_step "Creating and joining channel '${CHANNEL_NAME}'"
  (cd "$FABRIC_DIR" && "$FABRIC_SCRIPTS_DIR/channel.sh")
}

chaincode_committed() {
  fabric_env_law
  peer lifecycle chaincode querycommitted -C "$CHANNEL_NAME" -n "$CHAINCODE_NAME" 2>/dev/null | grep -q "Version: ${CHAINCODE_VERSION}"
}

deploy_chaincode() {
  CURRENT_STAGE="chaincode deployment"
  if chaincode_committed; then
    log_info "Chaincode '${CHAINCODE_NAME}' already committed on channel '${CHANNEL_NAME}'."
    return 0
  fi

  log_step "Deploying chaincode '${CHAINCODE_NAME}'"
  local ccaas_bash="$FABRIC_SCRIPTS_DIR/deploy-chaincode-ccaas.sh"
  local ccaas_ps1="$FABRIC_SCRIPTS_DIR/Deploy-Chaincode-CCaaS.ps1"

  case "$CHAINCODE_DEPLOY_MODE" in
    ccaas)
      if [[ -x "$ccaas_bash" ]]; then
        (cd "$FABRIC_DIR" && "$ccaas_bash")
      elif command -v pwsh >/dev/null 2>&1 && [[ -f "$ccaas_ps1" ]]; then
        (cd "$FABRIC_DIR" && pwsh -File "$ccaas_ps1")
      else
        log_warn "CCaaS mode requested but no compatible CCaaS deploy script available; falling back to legacy deploy script."
        (cd "$FABRIC_DIR" && "$FABRIC_SCRIPTS_DIR/deploy-chaincode.sh")
      fi
      ;;
    legacy)
      (cd "$FABRIC_DIR" && "$FABRIC_SCRIPTS_DIR/deploy-chaincode.sh")
      ;;
    auto|*)
      if [[ -x "$ccaas_bash" ]]; then
        (cd "$FABRIC_DIR" && "$ccaas_bash")
      elif command -v pwsh >/dev/null 2>&1 && [[ -f "$ccaas_ps1" ]]; then
        (cd "$FABRIC_DIR" && pwsh -File "$ccaas_ps1")
      else
        (cd "$FABRIC_DIR" && "$FABRIC_SCRIPTS_DIR/deploy-chaincode.sh")
      fi
      ;;
  esac
}

verify_chaincode_runtime() {
  CURRENT_STAGE="chaincode runtime verification"

  wait_until "chaincode committed on channel" "$RETRY_MAX" "$RETRY_SLEEP" "bash -lc 'source /dev/null 2>/dev/null; export CORE_PEER_LOCALMSPID=LawEnforcementMSP CORE_PEER_TLS_ENABLED=true CORE_PEER_TLS_ROOTCERT_FILE=\"$FABRIC_DIR/crypto-config/peerOrganizations/lawenforcement.evidentia.network/peers/peer0.lawenforcement.evidentia.network/tls/ca.crt\" CORE_PEER_MSPCONFIGPATH=\"$FABRIC_DIR/crypto-config/peerOrganizations/lawenforcement.evidentia.network/users/Admin@lawenforcement.evidentia.network/msp\" CORE_PEER_ADDRESS=localhost:7051; peer lifecycle chaincode querycommitted -C \"$CHANNEL_NAME\" -n \"$CHAINCODE_NAME\" | grep -q \"Version: $CHAINCODE_VERSION\"'"

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

  # D) query ledger state to verify transaction committed
  log_info "D) Querying ledger state through backend"
  local query_json
  query_json="$(curl -fsS "http://localhost:${BACKEND_PORT}/api/forensic/evidence/${evidence_id}" -H 'x-api-key: demo-tool-key')"
  echo "$query_json" | jq -e '.success == true and .data.evidenceId != null' >/dev/null || { log_error "Test failure at stage D: evidence query failed"; exit 1; }

  # E) IPFS version endpoint
  log_info "E) Querying IPFS version endpoint"
  local ipfs_json
  ipfs_json="$(curl -fsS "$IPFS_API_URL")"
  echo "$ipfs_json" | jq . >/dev/null || { log_error "Test failure at stage E: IPFS API not responding"; exit 1; }

  # F)
  log_info "F) SUCCESS: all startup and validation checks passed."
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
  log_info "Fabric/CouchDB/IPFS containers:"
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | awk 'NR==1 || /orderer\.evidentia\.network|peer0\.|couchdb\.|ipfs\.evidentia\.network/'

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
