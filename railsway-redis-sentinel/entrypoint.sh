#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[Redis-HA]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# -------------------------------------------------------------------------
# 1. Validation & Setup
# -------------------------------------------------------------------------

if [ -z "$REDIS_PASSWORD" ]; then
    error "REDIS_PASSWORD is required!"
    exit 1
fi

if [ -z "$INITIAL_MASTER_HOST" ]; then
    warn "INITIAL_MASTER_HOST not set. Defaulting to 'redis-node-1.railway.internal'"
    INITIAL_MASTER_HOST="redis-node-1.railway.internal"
fi

# Detect my own hostname/IP
MY_HOSTNAME=$(hostname)
# Try to resolve IP for better Sentinel communication
MY_IP=$(getent hosts "$MY_HOSTNAME" | awk '{ print $1 }')

if [ -z "$MY_IP" ]; then
    warn "Could not resolve my IP, using hostname: $MY_HOSTNAME"
    ANNOUNCE_IP="$MY_HOSTNAME"
else
    log "Resolved my IP: $MY_IP"
    ANNOUNCE_IP="$MY_IP" # Use IP for Sentinel announcement
fi

# Configuration Files
REDIS_CONF="/data/redis.conf"
SENTINEL_CONF="/data/sentinel.conf"

# Ensure data dir exists
mkdir -p /data
chown redis:redis /data

# -------------------------------------------------------------------------
# 2. Configure Redis (redis.conf)
# -------------------------------------------------------------------------

cat > "$REDIS_CONF" <<EOF
port $REDIS_PORT
bind 0.0.0.0 ::
protected-mode no
requirepass "$REDIS_PASSWORD"
masterauth "$REDIS_PASSWORD"
appendonly yes
EOF

# Replica Announcement (Important for NAT/Containers)
# echo "replica-announce-ip $ANNOUNCE_IP" >> "$REDIS_CONF"
# echo "replica-announce-port $REDIS_PORT" >> "$REDIS_CONF"

# -------------------------------------------------------------------------
# 3. Determine Role (Master vs Replica)
# -------------------------------------------------------------------------

log "Checking for existing Master..."

MASTER_HOST=""
MASTER_PORT="$REDIS_PORT"

# Try toping the defined "Initial Master"
if redis-cli -h "$INITIAL_MASTER_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" --no-auth-warning PING > /dev/null 2>&1; then
    # It is alive. confirm it is actually a master?
    ROLE=$(redis-cli -h "$INITIAL_MASTER_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" --no-auth-warning INFO replication | grep role | tr -d '\r')
    
    if [ "$ROLE" = "role:master" ]; then
        log "Found active Master at $INITIAL_MASTER_HOST"
        MASTER_HOST="$INITIAL_MASTER_HOST"
    else
        log "$INITIAL_MASTER_HOST is alive but not a master ($ROLE)."
        # It's a replica. Ask it who the master is? (Advanced, skip for now)
    fi
else
    log "Could not contact Initial Master ($INITIAL_MASTER_HOST)."
fi

# Decision Time
if [ -n "$MASTER_HOST" ]; then
    # We found a master, so we are a replica
    if [ "$MY_HOSTNAME" != "$MASTER_HOST" ] && [[ "$MY_HOSTNAME" != *"$MASTER_HOST"* ]]; then
        log "Configuring as REPLICA of $MASTER_HOST"
        echo "replicaof $MASTER_HOST $MASTER_PORT" >> "$REDIS_CONF"
    else
        log "I am the detected Master ($MASTER_HOST)."
    fi
else
    # No master found. Am I the Initial Master?
    # We check if our hostname contains the INITIAL_MASTER_HOST string (simple check)
    # OR if we are empty state.
    
    # Simple logic: If I am the INITIAL_MASTER_HOST, I will be master.
    # Otherwise, I will TRY to be a replica of it (and fail/retry until it comes up)
    
    # NOTE: In a fresh cluster deploy, wait for node-1.
    
    if [[ "$ANNOUNCE_IP" == *"$INITIAL_MASTER_HOST"* ]] || [[ "$INITIAL_MASTER_HOST" == *"$HOSTNAME"* ]]; then
         log "I am the Initial Master. Starting as MASTER."
         MASTER_HOST="127.0.0.1" # Self
    else
         log "Master not found. Configuring to retry connection to $INITIAL_MASTER_HOST..."
         echo "replicaof $INITIAL_MASTER_HOST $REDIS_PORT" >> "$REDIS_CONF"
         MASTER_HOST="$INITIAL_MASTER_HOST"
    fi
fi

# -------------------------------------------------------------------------
# 4. Configure Sentinel (sentinel.conf)
# -------------------------------------------------------------------------

# Note: Sentinel modifies this file, so we must recreate it if it doesn't exist 
# or reset it on fresh boot to avoid stale configs, BUT valid sentinels need persistent history.
# For simplicity in this template: We regenerate base config but keep state if possible?
# No, usually easier to regenerate pointing to the CURRENT master.

cat > "$SENTINEL_CONF" <<EOF
port $SENTINEL_PORT
bind 0.0.0.0 ::
protected-mode no
dir /data
sentinel monitor mymaster $MASTER_HOST $REDIS_PORT $SENTINEL_QUORUM
sentinel auth-pass mymaster $REDIS_PASSWORD
sentinel down-after-milliseconds mymaster $SENTINEL_DOWN_AFTER
sentinel failover-timeout mymaster $SENTINEL_FAILOVER
sentinel parallel-syncs mymaster 1
SENTINEL resolve-hostnames yes
SENTINEL announce-hostnames yes
EOF

# -------------------------------------------------------------------------
# 5. Start Services
# -------------------------------------------------------------------------

log "Starting Redis Server..."
redis-server "$REDIS_CONF" --daemonize yes

log "Waiting for Redis to start..."
sleep 2

log "Starting Sentinel..."
# We run Sentinel in foreground to keep container alive
exec redis-sentinel "$SENTINEL_CONF"
