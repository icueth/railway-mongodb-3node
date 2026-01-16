#!/bin/bash

# Path to the keyfile and database directory
KEYFILE_PATH="/data/keyfile"
DB_PATH="/data/db"
CONFIGDB_PATH="/data/configdb"

# Check if the keyfile already exists
if [ -f "$KEYFILE_PATH" ]; then
  echo "Keyfile already exists at $KEYFILE_PATH. Skipping keyfile generation."
else
  # Auto-generate keyfile from password and replica set name
  # This ensures all nodes generate the same keyfile deterministically
  
  if [ -z "$MONGO_INITDB_ROOT_PASSWORD" ]; then
    echo "ERROR: MONGO_INITDB_ROOT_PASSWORD is required for keyfile generation."
    exit 1
  fi
  
  if [ -z "$REPLICA_SET_NAME" ]; then
    echo "ERROR: REPLICA_SET_NAME is required for keyfile generation."
    exit 1
  fi
  
  echo "Auto-generating keyfile from credentials..."
  
  # Generate deterministic keyfile using password + replica set name
  # All nodes with same credentials will generate identical keyfile
  SEED="${MONGO_INITDB_ROOT_PASSWORD}:${REPLICA_SET_NAME}:mongodb-keyfile-seed"
  echo -n "$SEED" | openssl dgst -sha512 -binary | base64 -w 0 > "$KEYFILE_PATH"
  
  # Append more entropy to meet MongoDB's minimum keyfile length (6-1024 chars)
  echo "" >> "$KEYFILE_PATH"
  echo -n "${SEED}:extra" | openssl dgst -sha512 -binary | base64 -w 0 >> "$KEYFILE_PATH"
  
  chown mongodb:mongodb "$KEYFILE_PATH"
  chmod 600 "$KEYFILE_PATH"
  
  echo "Keyfile generated successfully at $KEYFILE_PATH"
fi

# Ensure the database directory exists
if [ ! -d "$DB_PATH" ]; then
  echo "Creating MongoDB data directory at $DB_PATH..."
  mkdir -p "$DB_PATH"
  chown -R mongodb:mongodb "$DB_PATH"
fi

# Ensure the configdb directory exists (prevents warning from docker-entrypoint.sh)
if [ ! -d "$CONFIGDB_PATH" ]; then
  mkdir -p "$CONFIGDB_PATH"
  chown -R mongodb:mongodb "$CONFIGDB_PATH"
fi
