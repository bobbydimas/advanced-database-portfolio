-- ============================================================================
-- MIT 8103: Advanced Database Systems - Portfolio 5
-- Distributed & Cloud Database Architecture: Regional Sharding & Partitioning
-- System: OrbitLink Ground Station & Satellite Telemetry Network (OGSTN)
-- ============================================================================

DROP TABLE IF EXISTS distributed_telemetry_ledger CASCADE;

-- 1. Create a Horizontally Partitioned (Sharded) Table by Ground Station Region
-- In a distributed cloud cluster (e.g., Citus / AWS Aurora / CockroachDB),
-- each partition maps to a dedicated regional database node.
CREATE TABLE distributed_telemetry_ledger (
    ledger_id BIGSERIAL,
    station_code VARCHAR(10) NOT NULL,
    satellite_id INTEGER NOT NULL,
    aos_timestamp TIMESTAMPTZ NOT NULL,
    downlink_volume_mb NUMERIC(10,2) NOT NULL,
    avg_snr_db NUMERIC(5,2) NOT NULL,
    replication_origin_node VARCHAR(30) NOT NULL,
    PRIMARY KEY (station_code, ledger_id)
) PARTITION BY LIST (station_code);

-- 2. Define Regional Shard Partitions (Simulating 4 Geo-Distributed Nodes)
CREATE TABLE shard_node_abj PARTITION OF distributed_telemetry_ledger
    FOR VALUES IN ('ABJ-GS01');

CREATE TABLE shard_node_kan PARTITION OF distributed_telemetry_ledger
    FOR VALUES IN ('KAN-GS02');

CREATE TABLE shard_node_lag PARTITION OF distributed_telemetry_ledger
    FOR VALUES IN ('LAG-GS03');

CREATE TABLE shard_node_jos PARTITION OF distributed_telemetry_ledger
    FOR VALUES IN ('JOS-GS04');

-- 3. Route 50,000 Contact Passes into the Geo-Partitioned Shards
INSERT INTO distributed_telemetry_ledger (
    station_code, satellite_id, aos_timestamp,
    downlink_volume_mb, avg_snr_db, replication_origin_node
)
SELECT 
    gs.station_code,
    cp.satellite_id,
    cp.aos_timestamp,
    cp.downlink_volume_mb,
    cp.avg_snr_db,
    'PRIMARY-' || gs.station_code AS replication_origin_node
FROM contact_passes cp
JOIN antennas a ON cp.antenna_id = a.antenna_id
JOIN ground_stations gs ON a.station_id = gs.station_id;

ANALYZE distributed_telemetry_ledger;

-- 4. Verify Shard Record Distribution Across the 4 Regional Nodes
\echo '=== SHARD DISTRIBUTION ACROSS REGIONAL NODES ==='
SELECT 
    tableoid::regclass AS regional_shard_partition,
    station_code,
    replication_origin_node,
    COUNT(*) AS records_stored,
    ROUND(SUM(downlink_volume_mb) / 1024.0, 2) AS shard_data_volume_gb
FROM distributed_telemetry_ledger
GROUP BY tableoid::regclass, station_code, replication_origin_node
ORDER BY records_stored DESC;

-- 5. Demonstrate Partition Pruning (Single-Shard Routing Optimization)
-- Notice that querying station_code = 'ABJ-GS01' scans ONLY shard_node_abj
-- and completely prunes/skips Kano, Lagos, and Jos shards!
\echo '=== DISTRIBUTED QUERY PLAN: SINGLE-SHARD PARTITION PRUNING ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT station_code, COUNT(*), AVG(avg_snr_db)
FROM distributed_telemetry_ledger
WHERE station_code = 'ABJ-GS01'
  AND aos_timestamp >= '2025-06-01 00:00:00+01'
GROUP BY station_code;
