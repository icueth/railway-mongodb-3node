FROM redis:7-alpine

# Install bash and gettext (for strict env substitution if needed, mainly bash)
RUN apk add --no-cache bash

# Copy scripts
COPY entrypoint.sh /entrypoint.sh
COPY healthcheck.sh /healthcheck.sh

# Make executable
RUN chmod +x /entrypoint.sh /healthcheck.sh

# Environment Defaults
ENV REDIS_PORT=6379
ENV SENTINEL_PORT=26379
ENV SENTINEL_QUORUM=2
ENV SENTINEL_DOWN_AFTER=5000
ENV SENTINEL_FAILOVER=10000

# Healthcheck
HEALTHCHECK --interval=10s --timeout=5s --retries=5 CMD /healthcheck.sh

ENTRYPOINT ["/entrypoint.sh"]
