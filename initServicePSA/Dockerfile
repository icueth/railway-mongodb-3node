# Base image - MongoDB 8
FROM mongo:8

# Install curl
RUN apt-get update && apt-get install -y curl

# Copy the initiation script into the container
COPY --chmod=755 initiate-replica-psa.sh /initiate-replica-psa.sh

# Set the entrypoint to the initiation script
ENTRYPOINT ["/bin/bash", "/initiate-replica-psa.sh"]
