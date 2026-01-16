#!/bin/bash

# Path to the keyfile and database directory
KEYFILE_PATH="/data/keyfile"
DB_PATH="/data/db"
CONFIGDB_PATH="/data/configdb"

generate_keyfile() {
  echo "Auto-generating keyfile from credentials..."
  
  # Generate deterministic keyfile using password + replica set name
  # All nodes with same credentials will generate identical keyfile
  SEED="${MONGO_INITDB_ROOT_PASSWORD}:${REPLICA_SET_NAME}:mongodb-keyfile-seed"
  
  # Use tr to remove newlines (works on all Linux distros, unlike base64 -w 0)
  KEYFILE_CONTENT=$(echo -n "$SEED" | openssl dgst -sha512 -binary | base64 | tr -d '\n')
  KEYFILE_EXTRA=$(echo -n "${SEED}:extra" | openssl dgst -sha512 -binary | base64 | tr -d '\n')
  
  # Write keyfile with proper format
  echo "${KEYFILE_CONTENT}" > "$KEYFILE_PATH"
  echo "${KEYFILE_EXTRA}" >> "$KEYFILE_PATH"
  
  chown mongodb:mongodb "$KEYFILE_PATH"
  chmod 600 "$KEYFILE_PATH"
  
  echo "Keyfile generated successfully at $KEYFILE_PATH"
}

# Validate required environment variables
if [ -z "$MONGO_INITDB_ROOT_PASSWORD" ]; then
  echo "ERROR: MONGO_INITDB_ROOT_PASSWORD is required for keyfile generation."
  exit 1
fi

if [ -z "$REPLICA_SET_NAME" ]; then
  echo "ERROR: REPLICA_SET_NAME is required for keyfile generation."
  exit 1
fi

# Force regenerate keyfile if requested
if [ "$FORCE_KEYFILE_REGENERATE" = "1" ] || [ "$FORCE_KEYFILE_REGENERATE" = "true" ]; then
  echo "FORCE_KEYFILE_REGENERATE is set. Regenerating keyfile..."
  rm -f "$KEYFILE_PATH"
  generate_keyfile
# Check if keyfile exists and is valid
elif [ -f "$KEYFILE_PATH" ]; then
  # Check if keyfile has correct permissions and is not empty
  KEYFILE_SIZE=$(stat -c%s "$KEYFILE_PATH" 2>/dev/null || stat -f%z "$KEYFILE_PATH" 2>/dev/null)
  
  if [ "$KEYFILE_SIZE" -lt 100 ]; then
    echo "Existing keyfile is too small or corrupted. Regenerating..."
    generate_keyfile
  else
    echo "Keyfile already exists at $KEYFILE_PATH. Validating..."
    
    # Check permissions
    KEYFILE_PERMS=$(stat -c%a "$KEYFILE_PATH" 2>/dev/null || stat -f%Lp "$KEYFILE_PATH" 2>/dev/null)
    if [ "$KEYFILE_PERMS" != "600" ]; then
      echo "Fixing keyfile permissions..."
      chmod 600 "$KEYFILE_PATH"
      chown mongodb:mongodb "$KEYFILE_PATH"
    fi
    
    echo "Keyfile validation complete."
  fi
else
  generate_keyfile
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
