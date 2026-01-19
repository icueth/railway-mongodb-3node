# ⚡️ Redis Sentinel High Availability on Railway

<p align="center">
  <strong>Deploy a production-ready Redis HA Cluster (Sentinel) on Railway in minutes</strong>
</p>

---

## 🏛️ Architecture

This template deploys a **3-Node Redis Sentinel Cluster**. Each node runs both a Redis instance and a Sentinel process, offering a compact and cost-effective High Availability solution on Railway.

- **Node 1**: Initial Master + Sentinel
- **Node 2**: Replica + Sentinel
- **Node 3**: Replica + Sentinel

If the Master fails, the Sentinels will detect it, reach a quorum, and automatically promote one of the Replicas to be the new Master.

---

## 🚀 Quick Start

### Step 1: Deploy 3 Services

Create 3 services on Railway using this template (or Dockerfile). Name them:

1. `redis-node-1`
2. `redis-node-2`
3. `redis-node-3`

### Step 2: Configure Environment Variables

Set these variables for **ALL 3 Services**:

| Variable              | Value                           | Description                                     |
| :-------------------- | :------------------------------ | :---------------------------------------------- |
| `REDIS_PASSWORD`      | `<your-secure-password>`        | Required for authentication                     |
| `INITIAL_MASTER_HOST` | `redis-node-1.railway.internal` | The bootstrap master hostname                   |
| `SENTINEL_QUORUM`     | `2`                             | Number of sentinels needed to agree on failover |
| `REDIS_PORT`          | `6379`                          | Default Redis port                              |
| `SENTINEL_PORT`       | `26379`                         | Default Sentinel port                           |

> ⚠️ **Important:** `INITIAL_MASTER_HOST` must match the internal hostname of your first node.

### Step 3: Connect to the Cluster

To use this HA cluster, your application client must support **Redis Sentinel**.

**Connection URL (Example for ioredis/node-redis):**

```javascript
const redis = new Redis({
  sentinels: [
    { host: "redis-node-1.railway.internal", port: 26379 },
    { host: "redis-node-2.railway.internal", port: 26379 },
    { host: "redis-node-3.railway.internal", port: 26379 },
  ],
  name: "mymaster",
  password: "your-secure-password",
});
```

---

## ⚙️ Configuration Details

### Failover Tuning

You can tweak these variables to adjust how fast failover happens:

- `SENTINEL_DOWN_AFTER`: Time (ms) before a node is considered down (Default: `5000` = 5s)
- `SENTINEL_FAILOVER`: Timeout (ms) for failover operation (Default: `10000` = 10s)

### Persistence

By default, this template enables AOF (Append Only File) persistence.

- To persist data across restarts, **add a Volume** mounted to `/data` for each service.

---

## 🧪 Testing Failover

1. Connect to the cluster and check current master.
2. Go to Railway dashboard and **Crash/Restart** the current Master node.
3. Watch the logs of other nodes. You should see messages like:
   - `+sdown master`
   - `+odown master`
   - `+vote-for-leader`
   - `+switch-master`
4. App should automatically reconnect to the new Master.

---

## 📄 License

MIT License
