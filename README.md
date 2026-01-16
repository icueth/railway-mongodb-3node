# 🍃 MongoDB Replica Set on Railway

<p align="center">
  <strong>Deploy a production-ready MongoDB PSA Replica Set on Railway in minutes</strong>
</p>

<p align="center">
  <a href="#-features">Features</a> •
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-architecture">Architecture</a> •
  <a href="#-configuration">Configuration</a> •
  <a href="#-troubleshooting">Troubleshooting</a>
</p>

---

## ✨ Features

- 🚀 **Easy Deployment** - Deploy a fully configured replica set with clear steps
- 🔐 **Secure Authentication** - Keyfile-based replica set authentication
- 🏗️ **PSA Architecture** - Primary, Secondary, Arbiter configuration for high availability
- 📦 **MongoDB 8** - Latest stable version with all modern features
- 🔄 **Auto Failover** - Automatic failover when primary goes down
- 🌐 **IPv6 Ready** - Full IPv6 support for Railway's internal network

---

## 🏁 Quick Start

### Step 1: Generate a Keyfile

Generate a secure keyfile that will be shared across all nodes:

```bash
openssl rand -base64 756
```

> ⚠️ **Important**: Copy the entire output. All nodes MUST use the **same keyfile**.

### Step 2: Deploy MongoDB Nodes

Deploy each node from their respective directories:

| Node          | Directory          | Volume Required |
| ------------- | ------------------ | --------------- |
| **Primary**   | `nodes/primary/`   | ✅ `/data`      |
| **Secondary** | `nodes/secondary/` | ✅ `/data`      |
| **Arbiter**   | `nodes/arbiter/`   | ❌ None         |

### Step 3: Set Environment Variables for Nodes

Set these variables for **all MongoDB nodes** (primary, secondary, arbiter):

```bash
KEYFILE=<paste-your-generated-keyfile-here>
REPLICA_SET_NAME=rs0
MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_PASSWORD=<your-secure-password>
```

> 🔐 **Critical**: The `KEYFILE` must be **exactly the same** on all three nodes!

### Step 4: Initialize Replica Set

1. Deploy the init service from `initServicePSA/`
2. Set these environment variables:

```bash
REPLICA_SET_NAME=rs0
MONGO_PRIMARY_HOST=mongo-primary.railway.internal
MONGO_SECONDARY_HOST=mongo-secondary.railway.internal
MONGO_ARBITER_HOST=mongo-arbiter.railway.internal
MONGO_PORT=27017
MONGOUSERNAME=admin
MONGOPASSWORD=<your-secure-password>
```

3. Wait for the init service to complete
4. **Delete the init service** after seeing "PLEASE DELETE THIS SERVICE"

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
│   ├── 📄 Dockerfile              # Shared Dockerfile template
│   ├── 📄 generate-keyfile.sh     # Keyfile setup script
│   ├── 📂 primary/                # Primary node
│   ├── 📂 secondary/              # Secondary node
│   └── 📂 arbiter/                # Arbiter node
├── 📂 initServicePSA/             # PSA replica set initializer
│   ├── 📄 Dockerfile
│   ├── 📄 initiate-replica-psa.sh
│   └── 📄 railway.json
├── 📄 exampleENV                  # Environment template
├── 📄 LICENSE
└── 📄 README.md
```

---

## ⚙️ Configuration

### Environment Variables

#### MongoDB Nodes (Primary, Secondary, Arbiter)

| Variable                     | Description                             | Required |
| ---------------------------- | --------------------------------------- | -------- |
| `KEYFILE`                    | Base64-encoded keyfile (from openssl)   | ✅       |
| `REPLICA_SET_NAME`           | Replica set identifier (default: `rs0`) | ✅       |
| `MONGO_INITDB_ROOT_USERNAME` | Admin username                          | ✅       |
| `MONGO_INITDB_ROOT_PASSWORD` | Admin password                          | ✅       |

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

## 🔗 Connection String

After successful initialization:

```
mongodb://admin:<password>@mongo-primary.railway.internal:27017,mongo-secondary.railway.internal:27017/?replicaSet=rs0&authSource=admin
```

> 💡 The arbiter is not included in connection strings as it doesn't store data.

---

## 🌍 External Connection

To connect from outside Railway (e.g., your local machine), you must expose the **Primary Node** publicly.

### Steps:

1. Go to `mongo-primary` service settings on Railway
2. Under "Networking", click **"Generate Domain"** (or Custom Domain)
3. You will get a TCP Proxy address, e.g., `roundhouse.proxy.rlwy.net:12345`

### Connection String (Primary Only)

Due to internal DNS resolution limits, external connections act as a **Direct Connection** to the primary node:

```
mongodb://admin:<password>@<tcp-proxy-host>:<tcp-proxy-port>/?directConnection=true&authSource=admin
```

> ⚠️ **Note**: This connects directly to the Primary node. It does not provide automatic failover for external clients, but is useful for administration/debugging.

---

## 🔒 Security Best Practices

- ✅ Use **strong, unique passwords** for production
- ✅ Keep the **keyfile secret** - anyone with it can join the replica set
- ✅ Use the **same keyfile** on all nodes
- ✅ Use **Railway's internal networking** for inter-node communication
- ✅ Regularly **rotate credentials**

---

## 🔧 Troubleshooting

### "Cannot select sync source because it is not readable"

**Cause**: Keyfile mismatch between nodes

**Solution**:

1. Verify `KEYFILE` is **exactly the same** on all nodes
2. Delete volumes on all nodes
3. Redeploy all nodes
4. Redeploy init service

### "Read security file failed"

**Cause**: Keyfile is missing or has wrong format

**Solution**:

1. Ensure `KEYFILE` environment variable is set
2. Keyfile should be base64-encoded string
3. Check for extra spaces or newlines in the value

### "No primary exists"

**Cause**: Replica set not initialized yet

**Solution**:

1. Wait for all nodes to be online first
2. Check init service logs
3. Redeploy init service

### Common Warnings (Can Be Ignored)

- `vm.max_map_count is too low` - Kernel parameter, cannot change on Railway
- `swappiness` - Kernel parameter, cannot change on Railway
- `Automatically disabling TLS 1.0 and TLS 1.1` - Expected behavior

---

## 📝 Deployment Checklist

```
□ 1. Generate keyfile: openssl rand -base64 756
□ 2. Copy keyfile to a safe place
□ 3. Deploy mongo-primary from nodes/primary/
□ 4. Deploy mongo-secondary from nodes/secondary/
□ 5. Deploy mongo-arbiter from nodes/arbiter/
□ 6. Add volume /data to primary and secondary
□ 7. Set environment variables on ALL nodes (same KEYFILE!)
□ 8. Wait for all nodes to be Online
□ 9. Deploy init service from initServicePSA/
□ 10. Set environment variables on init service
□ 11. Check init service logs for success
□ 12. Delete init service after initialization
□ 13. Test connection using connection string
```

---

## 📄 License

MIT License - see [LICENSE](LICENSE)

---

Ref: https://github.com/railwayapp-templates/mongo-replica-set

<p align="center">
  Made with ❤️ for the <a href="https://railway.app">Railway</a> community
</p>
