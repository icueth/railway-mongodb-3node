# MongoDB 8 Replica Set Node
FROM mongo:8

# Copy the setup script
COPY generate-keyfile.sh /generate-keyfile.sh

# Make the script executable
RUN chmod +x /generate-keyfile.sh

# Default replica set name
ENV REPLICA_SET_NAME=rs0

# Entrypoint: setup keyfile then start MongoDB
ENTRYPOINT ["/bin/bash", "-c", "/generate-keyfile.sh && exec docker-entrypoint.sh mongod --replSet ${REPLICA_SET_NAME} --auth --keyFile /data/keyfile --ipv6 --bind_ip ::,0.0.0.0"]
