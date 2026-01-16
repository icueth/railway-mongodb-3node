#!/bin/bash
set -e

# ============================================================
# MongoDB Keyfile Setup Script
# ============================================================
# This script writes the KEYFILE environment variable to a file
# and ensures proper permissions for MongoDB replica set auth.
# ============================================================

KEYFILE_PATH="/data/keyfile"
DB_PATH="/data/db"
CONFIGDB_PATH="/data/configdb"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

setup_keyfile() {
  log_info "Setting up keyfile from KEYFILE environment variable..."
  
  # Ensure /data directory exists
  mkdir -p "$(dirname "$KEYFILE_PATH")"
  
  # Write keyfile content
  echo "$KEYFILE" > "$KEYFILE_PATH"
  
  # Set proper ownership and permissions (required by MongoDB)
  chown mongodb:mongodb "$KEYFILE_PATH"
  chmod 600 "$KEYFILE_PATH"
  
  log_info "Keyfile created successfully at $KEYFILE_PATH"
}

validate_keyfile() {
  if [ ! -f "$KEYFILE_PATH" ]; then
    return 1
  fi
  
  # Check file size (must be at least 6 characters)
  local keyfile_size
  keyfile_size=$(stat -c%s "$KEYFILE_PATH" 2>/dev/null || stat -f%z "$KEYFILE_PATH" 2>/dev/null || echo "0")
  
  if [ "$keyfile_size" -lt 6 ]; then
    log_warn "Keyfile is too small ($keyfile_size bytes)"
    return 1
  fi
  
  # Check and fix permissions if needed
  local keyfile_perms
  keyfile_perms=$(stat -c%a "$KEYFILE_PATH" 2>/dev/null || stat -f%Lp "$KEYFILE_PATH" 2>/dev/null || echo "000")
  
  if [ "$keyfile_perms" != "600" ]; then
    log_warn "Fixing keyfile permissions ($keyfile_perms -> 600)..."
    chmod 600 "$KEYFILE_PATH"
    chown mongodb:mongodb "$KEYFILE_PATH"
  fi
  
  return 0
}

setup_directories() {
  # Create database directory
  if [ ! -d "$DB_PATH" ]; then
    log_info "Creating MongoDB data directory at $DB_PATH..."
    mkdir -p "$DB_PATH"
    chown -R mongodb:mongodb "$DB_PATH"
  fi
  
  # Create configdb directory (prevents warning from docker-entrypoint.sh)
  if [ ! -d "$CONFIGDB_PATH" ]; then
    mkdir -p "$CONFIGDB_PATH"
    chown -R mongodb:mongodb "$CONFIGDB_PATH"
  fi
}

# ============================================================
# Main Script
# ============================================================

echo "============================================================"
echo "  MongoDB Replica Set Node - Setup"
echo "============================================================"

# Validate required environment variables
if [ -z "$KEYFILE" ]; then
  log_error "KEYFILE environment variable is required!"
  log_error ""
  log_error "Generate a keyfile using:"
  log_error "  openssl rand -base64 756"
  log_error ""
  log_error "Then set KEYFILE environment variable with the output."
  exit 1
fi

if [ -z "$REPLICA_SET_NAME" ]; then
  log_warn "REPLICA_SET_NAME not set, using default: rs0"
  export REPLICA_SET_NAME="rs0"
fi

log_info "Replica Set Name: $REPLICA_SET_NAME"

# Setup directories first
setup_directories

# Handle keyfile
if [ -f "$KEYFILE_PATH" ]; then
  if validate_keyfile; then
    log_info "Existing keyfile is valid."
  else
    log_warn "Existing keyfile is invalid. Recreating..."
    setup_keyfile
  fi
else
  setup_keyfile
fi

echo "============================================================"
echo "  Setup Complete - Starting MongoDB..."
echo "============================================================"
