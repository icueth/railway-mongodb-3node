#!/bin/bash
set -e

# Check Redis
redis-cli -p "$REDIS_PORT" -a "$REDIS_PASSWORD" --no-auth-warning PING | grep -q "PONG" || exit 1

# Check Sentinel
redis-cli -p "$SENTINEL_PORT" PING | grep -q "PONG" || exit 1

exit 0
