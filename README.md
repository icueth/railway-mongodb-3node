# 🍃 MongoDB Replica Set on Railway

<p align="center">
  <img src="https://www.mongodb.com/assets/images/global/MongoDB_Logo_Dark_RGB.svg" alt="MongoDB Logo" width="400">
</p>

<p align="center">
  <strong>Deploy a production-ready MongoDB Replica Set on Railway in minutes</strong>
</p>

<p align="center">
  <a href="#-features">Features</a> •
  <a href="#-quick-start">Quick Start</a> •
  <a href="#️-architecture">Architecture</a> •
  <a href="#-configuration">Configuration</a> •
  <a href="#-deployment">Deployment</a>
</p>

---

## ✨ Features

- 🚀 **One-Click Deployment** - Deploy a fully configured replica set with minimal setup
- 🔐 **Auto-Generated Keyfile** - Secure keyfile automatically generated from credentials
- 🏗️ **PSA Architecture** - Primary, Secondary, Arbiter configuration for high availability
- 📦 **MongoDB 8** - Latest stable version with all modern features
- 🔄 **Auto Failover** - Automatic failover when primary goes down
- 🌐 **IPv6 Ready** - Full IPv6 support for Railway's internal network

---

## 🏁 Quick Start

### 1. Deploy on Railway

Deploy each node from their respective directories:

| Node          | Directory          | Volume Required |
| ------------- | ------------------ | --------------- |
| **Primary**   | `nodes/primary/`   | ✅ `/data`      |
| **Secondary** | `nodes/secondary/` | ✅ `/data`      |
| **Arbiter**   | `nodes/arbiter/`   | ❌ None         |

### 2. Set Environment Variables

Set these variables for all MongoDB nodes:

```bash
REPLICA_SET_NAME=rs0
MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_PASSWORD=<your-secure-password>
```

> 💡 **Note**: Keyfile is **automatically generated** from your credentials - no manual setup required!

### 3. Initialize Replica Set

Deploy the init service from `initServicePSA/` and wait for completion.

---

## 🏛️ Architecture

```
                    ┌─────────────────┐
                    │    Clients      │
                    └────────┬────────┘
                             │
                             ▼
    ┌────────────────────────────────────────────────┐
    │              MongoDB Replica Set                │
    │                                                 │
    │  ┌───────────┐  ┌───────────┐  ┌───────────┐   │
    │  │  PRIMARY  │  │ SECONDARY │  │  ARBITER  │   │
    │  │           │  │           │  │           │   │
    │  │ • Read    │  │ • Read    │  │ • Vote    │   │
    │  │ • Write   │  │ • Replica │  │ • No Data │   │
    │  │           │  │           │  │           │   │
    │  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘   │
    │        │              │              │         │
    │        └──────────────┼──────────────┘         │
    │                       │                        │
    │              Replication & Voting              │
    └────────────────────────────────────────────────┘
```

### Node Roles

| Role          | Description                    | Data Storage | Can Become Primary |
| ------------- | ------------------------------ | ------------ | ------------------ |
| **Primary**   | Handles all write operations   | ✅ Yes       | Already Primary    |
| **Secondary** | Replicates data from Primary   | ✅ Yes       | ✅ Yes             |
| **Arbiter**   | Participates in elections only | ❌ No        | ❌ No              |

---

## 📁 Project Structure

```
railsway-mongodb-3node/
├── 📂 nodes/
│   ├── 📂 primary/              # Primary node configuration
│   │   ├── Dockerfile           # MongoDB 8 image setup
│   │   └── generate-keyfile.sh  # Keyfile generator
│   ├── 📂 secondary/            # Secondary node configuration
│   │   ├── Dockerfile
│   │   └── generate-keyfile.sh
│   └── 📂 arbiter/              # Arbiter node configuration
│       ├── Dockerfile
│       └── generate-keyfile.sh
├── 📂 initServicePSA/           # Replica set initializer
│   ├── Dockerfile
│   ├── initiate-replica-psa.sh  # PSA initialization script
│   └── railway.json
├── 📄 exampleENV                 # Environment template
├── 📄 LICENSE                    # MIT License
└── 📄 README.md                  # This file
```

---

## ⚙️ Configuration

### Environment Variables

#### MongoDB Nodes

| Variable                     | Description                                       | Required |
| ---------------------------- | ------------------------------------------------- | -------- |
| `REPLICA_SET_NAME`           | Replica set identifier (e.g., `rs0`)              | ✅       |
| `MONGO_INITDB_ROOT_USERNAME` | Admin username                                    | ✅       |
| `MONGO_INITDB_ROOT_PASSWORD` | Admin password (also used for keyfile generation) | ✅       |

> 🔐 **Auto-Generated Keyfile**: The keyfile is automatically generated using your `MONGO_INITDB_ROOT_PASSWORD` and `REPLICA_SET_NAME`. All nodes with the same credentials will have identical keyfiles.

#### Init Service

| Variable               | Description                            | Required |
| ---------------------- | -------------------------------------- | -------- |
| `REPLICA_SET_NAME`     | Must match nodes' replica set name     | ✅       |
| `MONGO_PRIMARY_HOST`   | Primary node hostname                  | ✅       |
| `MONGO_SECONDARY_HOST` | Secondary node hostname                | ✅       |
| `MONGO_ARBITER_HOST`   | Arbiter node hostname                  | ✅       |
| `MONGO_PORT`           | MongoDB port (default: `27017`)        | ❌       |
| `MONGOUSERNAME`        | Admin username                         | ✅       |
| `MONGOPASSWORD`        | Admin password                         | ✅       |
| `DEBUG`                | Enable verbose logging (`1` to enable) | ❌       |

---

## � Deployment

### Step-by-Step Guide

#### 1️⃣ Create Services on Railway

Create **4 services** in your Railway project:

```
mongo-primary      → Build from: nodes/primary/
mongo-secondary    → Build from: nodes/secondary/
mongo-arbiter      → Build from: nodes/arbiter/
mongo-init         → Build from: initServicePSA/
```

#### 2️⃣ Configure Volumes

| Service           | Volume Mount Point     |
| ----------------- | ---------------------- |
| `mongo-primary`   | `/data`                |
| `mongo-secondary` | `/data`                |
| `mongo-arbiter`   | None (no data storage) |

#### 3️⃣ Set Environment Variables

Create shared variables for all MongoDB nodes:

```bash
REPLICA_SET_NAME=rs0
MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_PASSWORD=<strong-password>
```

> 🔐 Keyfile is **automatically generated** - no manual setup needed!

For the init service:

```bash
MONGO_PRIMARY_HOST=mongo-primary.railway.internal
MONGO_SECONDARY_HOST=mongo-secondary.railway.internal
MONGO_ARBITER_HOST=mongo-arbiter.railway.internal
MONGOUSERNAME=admin
MONGOPASSWORD=<strong-password>
REPLICA_SET_NAME=rs0
```

#### 4️⃣ Deploy & Initialize

1. Deploy all MongoDB node services first
2. Wait for all nodes to be healthy
3. Deploy the init service
4. Check init service logs for success message
5. **Delete the init service** after successful initialization

---

## 🔗 Connection String

After successful initialization, use this connection string:

```
mongodb://<username>:<password>@mongo-primary.railway.internal:27017,mongo-secondary.railway.internal:27017/?replicaSet=rs0&authSource=admin
```

> 💡 **Note**: The arbiter is not included in connection strings as it doesn't store data.

### Connection Examples

#### Node.js

```javascript
const { MongoClient } = require("mongodb");

const uri =
  "mongodb://admin:password@mongo-primary.railway.internal:27017,mongo-secondary.railway.internal:27017/?replicaSet=rs0&authSource=admin";
const client = new MongoClient(uri);

async function connect() {
  await client.connect();
  console.log("Connected to MongoDB Replica Set");
}
```

#### Python

```python
from pymongo import MongoClient

uri = "mongodb://admin:password@mongo-primary.railway.internal:27017,mongo-secondary.railway.internal:27017/?replicaSet=rs0&authSource=admin"
client = MongoClient(uri)

# Verify connection
print(client.server_info())
```

---

## 🔒 Security Best Practices

- ✅ Use **strong, unique passwords** for production
- ✅ Keep the **keyfile secure** and consistent across all nodes
- ✅ Use **Railway's internal networking** for inter-node communication
- ✅ Enable **TLS/SSL** for production deployments
- ✅ Regularly **rotate credentials** and keyfiles
- ✅ Implement **proper access controls** and user roles

---

## 🔧 Troubleshooting

### Common Issues

<details>
<summary><strong>Replica set initialization failed</strong></summary>

1. Ensure all nodes are running and healthy
2. Verify all nodes use the **same keyfile**
3. Check that hostnames are correctly set
4. Enable `DEBUG=1` on init service for verbose logs

</details>

<details>
<summary><strong>Authentication failed</strong></summary>

1. Verify username/password are correct
2. Ensure `authSource=admin` is in connection string
3. Check that credentials match across all services

</details>

<details>
<summary><strong>Connection timeout</strong></summary>

1. Verify services are deployed in the same Railway project
2. Use internal hostnames (`.railway.internal`)
3. Check that port 27017 is accessible

</details>

---

## 📝 Changelog

| Version  | Changes                                |
| -------- | -------------------------------------- |
| **v2.0** | Updated to MongoDB 8, PSA architecture |
| **v1.0** | Initial release with MongoDB 7         |

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

Contributions are welcome! Feel free to:

- 🐛 Report bugs
- 💡 Suggest features
- 🔧 Submit pull requests

---

Ref: https://github.com/railwayapp-templates/mongo-replica-set

<p align="center">
  Made with ❤️ for the <a href="https://railway.app">Railway</a> community
</p>
