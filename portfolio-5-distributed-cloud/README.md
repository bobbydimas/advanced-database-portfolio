# Portfolio 5: Distributed and Cloud Database Architecture

## 1. Geo-Distributed Cloud Topology for OrbitLink (OGSTN)
Because OrbitLink operates four physically separated tracking facilities across Nigeria — Abuja (ABJ-GS01), Kano (KAN-GS02), Lagos (LAG-GS03), and Jos (JOS-GS04) — relying on a single centralized on-premise database introduces a Single Point of Failure (SPOF) and wide-area network (WAN) latency during real-time satellite passes.

### Cloud Deployment Architecture
* Primary Coordinator & Command Core (Abuja Cloud Region / Primary Node): Hosts the authoritative write leader for mission_operators, satellites, and uplink_commands where strict global ordering is mandatory.
* Regional Edge Shards (Abuja, Kano, Lagos, Jos Nodes): Each ground station facility writes pass metrics and high-frequency telemetry locally to its regional shard partition (shard_node_abj, shard_node_kan, shard_node_lag, shard_node_jos) and asynchronously replicates aggregated summaries to the central cloud analytics cluster.

---

## 2. Horizontal Sharding (Partitioning) Strategy
In distributed_sharding_setup.sql, the 50,000-row telemetry ledger is horizontally partitioned by list on the shard key station_code:
* Shard 1 (shard_node_abj): Stores all passes handled by the Lugbe Space Tracking Complex (ABJ-GS01).
* Shard 2 (shard_node_kan): Stores all passes handled by the Kano Northern Telemetry Array (KAN-GS02).
* Shard 3 (shard_node_lag): Stores all passes handled by the Epe Coastal Downlink Facility (LAG-GS03).
* Shard 4 (shard_node_jos): Stores all passes handled by the Plateau Deep Space Dish (JOS-GS04).

### Partition Pruning Verification
When an engineer in Abuja queries pass performance for station_code = 'ABJ-GS01', the query planner performs Partition Pruning: it routes the read operation exclusively to shard_node_abj and eliminates scanning the Kano, Lagos, and Jos partitions entirely, reducing I/O overhead by ~75%.

---

## 3. Replication, High Availability, and Consistency (CAP & PACELC Analysis)

### Workload-Specific Replication Models
1. Command Uplinks & Pass Scheduling (CP - Consistency + Partition Tolerance):
   * Uses Synchronous Quorum Replication (Raft / Multi-AZ Standby).
   * Before an antenna slew or spacecraft command is marked TRANSMITTED, at least a majority quorum of nodes must acknowledge the write-ahead log (WAL). This prevents split-brain double-booking of parabolic dishes if a fiber link drops.
2. Downlink Telemetry Ingestion (AP - Availability + Partition Tolerance):
   * Uses Asynchronous Leader-Follower Streaming Replication.
   * During an 11-minute LEO satellite pass, the ground station cannot halt telemetry ingestion if the WAN link to central headquarters fluctuates. Local station nodes buffer writes immediately (prioritizing Availability) and reconcile state via eventual consistency once connectivity restores.

### PACELC Theorem Classification
* For Uplink Scheduling (PC/EC): If a network Partition (P) occurs, the system chooses Consistency (C) by rejecting unverified cross-site antenna overrides; Else (E) during normal operation, it still prioritizes Consistency (C) over minimum write latency.
* For Telemetry Logging (PA/EL): If a Partition (P) occurs, the regional ground station chooses Availability (A) to capture every downlink packet locally; Else (E) in normal operation, it chooses low Latency (L) via asynchronous streaming replication.
