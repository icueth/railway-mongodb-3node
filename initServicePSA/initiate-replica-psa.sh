#!/bin/bash
set -e

# ============================================================
# MongoDB PSA Replica Set Initializer
# Primary + Secondary + Arbiter Configuration
# ============================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_debug() { [[ "$DEBUG" == "1" ]] && echo -e "${CYAN}[DEBUG]${NC} $1" || true; }

print_banner() {
  echo ""
  echo "============================================================"
  echo "  MongoDB PSA Replica Set Initializer"
  echo "  (Primary + Secondary + Arbiter)"
  echo "============================================================"
  echo ""
}

# Default port
MONGO_PORT=${MONGO_PORT:-27017}

check_mongo() {
  local host=$1
  local port=$2
  local max_retries=${3:-60}
  local retry_count=0
  
  log_info "Waiting for MongoDB at $host:$port..."
  
  while [ $retry_count -lt $max_retries ]; do
    if mongosh --host "$host" --port "$port" --eval "db.adminCommand('ping')" &>/dev/null; then
      log_info "✓ MongoDB at $host:$port is ready"
      return 0
    fi
    
    retry_count=$((retry_count + 1))
    log_debug "Attempt $retry_count/$max_retries - Waiting..."
    sleep 2
  done
  
  log_error "✗ MongoDB at $host:$port is not available after $max_retries attempts"
  return 1
}

wait_for_all_nodes() {
  log_info "Waiting for all nodes to be ready..."
  
  check_mongo "$MONGO_PRIMARY_HOST" "$MONGO_PORT" 90 || return 1
  check_mongo "$MONGO_SECONDARY_HOST" "$MONGO_PORT" 90 || return 1
  check_mongo "$MONGO_ARBITER_HOST" "$MONGO_PORT" 90 || return 1
  
  log_info "All nodes are ready!"
  return 0
}

check_already_initialized() {
  log_info "Checking if replica set is already initialized..."
  
  local result
  result=$(mongosh --host "$MONGO_PRIMARY_HOST" --port "$MONGO_PORT" \
    --username "$MONGOUSERNAME" --password "$MONGOPASSWORD" \
    --authenticationDatabase "admin" \
    --eval "rs.status().ok" 2>/dev/null || echo "0")
  
  if [ "$result" = "1" ]; then
    log_warn "Replica set is already initialized!"
    return 0
  fi
  
  return 1
}

initiate_psa_replica_set() {
  log_info "Initiating PSA Replica Set..."
  log_debug "Primary: $MONGO_PRIMARY_HOST:$MONGO_PORT"
  log_debug "Secondary: $MONGO_SECONDARY_HOST:$MONGO_PORT"
  log_debug "Arbiter: $MONGO_ARBITER_HOST:$MONGO_PORT"
  
  mongosh --host "$MONGO_PRIMARY_HOST" --port "$MONGO_PORT" \
    --username "$MONGOUSERNAME" --password "$MONGOPASSWORD" \
    --authenticationDatabase "admin" <<EOF
rs.initiate({
  _id: "$REPLICA_SET_NAME",
  members: [
    { _id: 0, host: "$MONGO_PRIMARY_HOST:$MONGO_PORT", priority: 2 },
    { _id: 1, host: "$MONGO_SECONDARY_HOST:$MONGO_PORT", priority: 1 },
    { _id: 2, host: "$MONGO_ARBITER_HOST:$MONGO_PORT", arbiterOnly: true }
  ]
})
EOF
  return $?
}

print_success() {
  echo ""
  echo "============================================================"
  echo -e "${GREEN}  ✓ PSA Replica Set Initiated Successfully!${NC}"
  echo "============================================================"
  echo ""
  echo "  Primary:   $MONGO_PRIMARY_HOST:$MONGO_PORT"
  echo "  Secondary: $MONGO_SECONDARY_HOST:$MONGO_PORT"
  echo "  Arbiter:   $MONGO_ARBITER_HOST:$MONGO_PORT"
  echo ""
  echo "  Connection String:"
  echo "  mongodb://$MONGOUSERNAME:<password>@$MONGO_PRIMARY_HOST:$MONGO_PORT,$MONGO_SECONDARY_HOST:$MONGO_PORT/?replicaSet=$REPLICA_SET_NAME&authSource=admin"
  echo ""
  echo -e "${YELLOW}  ⚠️  PLEASE DELETE THIS SERVICE NOW!${NC}"
  echo ""
  echo "============================================================"
}

print_failure() {
  echo ""
  echo "============================================================"
  echo -e "${RED}  ✗ Failed to Initialize Replica Set${NC}"
  echo "============================================================"
  echo ""
  echo "  Troubleshooting:"
  echo "  1. Check if all nodes are running and healthy"
  echo "  2. Verify KEYFILE is the same on all nodes"
  echo "  3. Verify environment variables are correct"
  echo "  4. Set DEBUG=1 for verbose logging"
  echo "  5. Check MongoDB logs on each node"
  echo ""
  echo "============================================================"
}

# ============================================================
# Main Script
# ============================================================

print_banner

# Validate environment variables
if [ -z "$MONGO_PRIMARY_HOST" ] || [ -z "$MONGO_SECONDARY_HOST" ] || [ -z "$MONGO_ARBITER_HOST" ]; then
  log_error "Missing required environment variables!"
  log_error "Required: MONGO_PRIMARY_HOST, MONGO_SECONDARY_HOST, MONGO_ARBITER_HOST"
  exit 1
fi

if [ -z "$MONGOUSERNAME" ] || [ -z "$MONGOPASSWORD" ]; then
  log_error "Missing credentials!"
  log_error "Required: MONGOUSERNAME, MONGOPASSWORD"
  exit 1
fi

REPLICA_SET_NAME=${REPLICA_SET_NAME:-rs0}
log_info "Replica Set Name: $REPLICA_SET_NAME"

# Wait for all nodes
if ! wait_for_all_nodes; then
  print_failure
  exit 1
fi

# Check if already initialized
if check_already_initialized; then
  print_success
  exit 0
fi

# Initialize replica set
if initiate_psa_replica_set; then
  log_info "Waiting for election to complete..."
  sleep 10
  print_success
  exit 0
else
  print_failure
  exit 1
fi
