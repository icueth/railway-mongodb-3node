#!/bin/bash

set -e

debug_log() {
  if [[ "$DEBUG" == "1" ]]; then
    echo "DEBUG: $1"
  fi
}

print_on_start() {
  echo "**********************************************************"
  echo "*                                                        *"
  echo "*  Deploying a Mongo PSA Replica Set to Railway...       *"
  echo "*  (Primary + Secondary + Arbiter)                       *"
  echo "*                                                        *"
  echo "*  To enable verbose logging, set DEBUG=1                *"
  echo "*  and redeploy the service.                             *"
  echo "*                                                        *"
  echo "**********************************************************"
}

check_mongo() {
  local host=$1
  local port=$2
  mongo_output=$(mongosh --host "$host" --port "$port" --eval "db.adminCommand('ping')" 2>&1)
  mongo_exit_code=$?
  debug_log "MongoDB check exit code: $mongo_exit_code"
  debug_log "MongoDB check output: $mongo_output"
  return $mongo_exit_code
}

check_all_nodes() {
  local nodes=("$@")
  for node in "${nodes[@]}"; do
    local host=$(echo $node | cut -d: -f1)
    local port=$(echo $node | cut -d: -f2)
    echo "Waiting for MongoDB to be available at $host:$port"
    until check_mongo "$host" "$port"; do
      echo "Waiting..."
      sleep 2
    done
  done
  echo "All MongoDB nodes are up."
}

initiate_psa_replica_set() {
  echo "Initiating PSA (Primary-Secondary-Arbiter) replica set."
  debug_log "_id: $REPLICA_SET_NAME"
  debug_log "Primary member: $MONGO_PRIMARY_HOST:$MONGO_PORT"
  debug_log "Secondary member: $MONGO_SECONDARY_HOST:$MONGO_PORT"
  debug_log "Arbiter member: $MONGO_ARBITER_HOST:$MONGO_PORT"

  mongosh --host "$MONGO_PRIMARY_HOST" --port "$MONGO_PORT" --username "$MONGOUSERNAME" --password "$MONGOPASSWORD" --authenticationDatabase "admin" <<EOF
rs.initiate({
  _id: "$REPLICA_SET_NAME",
  members: [
    { _id: 0, host: "$MONGO_PRIMARY_HOST:$MONGO_PORT", priority: 2 },
    { _id: 1, host: "$MONGO_SECONDARY_HOST:$MONGO_PORT", priority: 1 },
    { _id: 2, host: "$MONGO_ARBITER_HOST:$MONGO_PORT", arbiterOnly: true }
  ]
})
EOF
  init_exit_code=$?
  debug_log "PSA replica set initiation exit code: $init_exit_code"
  return $init_exit_code
}

# Default port if not set
MONGO_PORT=${MONGO_PORT:-27017}

nodes=("$MONGO_PRIMARY_HOST:$MONGO_PORT" "$MONGO_SECONDARY_HOST:$MONGO_PORT" "$MONGO_ARBITER_HOST:$MONGO_PORT")

print_on_start

check_all_nodes "${nodes[@]}"

if initiate_psa_replica_set; then
  echo "**********************************************************"
  echo "**********************************************************"
  echo "*                                                        *"
  echo "*    PSA Replica set initiated successfully.             *"
  echo "*                                                        *"
  echo "*    - Primary:   $MONGO_PRIMARY_HOST:$MONGO_PORT        *"
  echo "*    - Secondary: $MONGO_SECONDARY_HOST:$MONGO_PORT      *"
  echo "*    - Arbiter:   $MONGO_ARBITER_HOST:$MONGO_PORT        *"
  echo "*                                                        *"
  echo "*              PLEASE DELETE THIS SERVICE.               *"
  echo "*                                                        *"
  echo "**********************************************************"
  exit 0
else
  echo "**********************************************************"
  echo "**********************************************************"
  echo "*                                                        *"
  echo "*           Failed to initiate PSA replica set.          *"
  echo "*                                                        *"
  echo "*           Please check the MongoDB service logs        *"
  echo "*                 for more information.                  *"
  echo "*                                                        *"
  echo "*          You can also set DEBUG=1 as a variable        *"
  echo "*            on this service for verbose logging.        *"
  echo "*                                                        *"
  echo "**********************************************************"
  exit 1
fi
