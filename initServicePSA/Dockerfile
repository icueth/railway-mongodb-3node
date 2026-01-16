# MongoDB Init Service for PSA Replica Set
FROM mongo:8.2.3

# Install required tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy the initialization script
COPY --chmod=755 initiate-replica-psa.sh /initiate-replica-psa.sh

# Set default environment variables
ENV MONGO_PORT=27017
ENV REPLICA_SET_NAME=rs0
ENV DEBUG=0

# Run the initialization script
ENTRYPOINT ["/bin/bash", "/initiate-replica-psa.sh"]
