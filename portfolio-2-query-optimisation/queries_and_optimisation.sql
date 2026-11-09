-- ============================================================================
-- MIT 8103: Advanced Database Systems - Portfolio 2
-- Analytical Queries, Execution Plans (EXPLAIN ANALYZE), and Indexing
-- ============================================================================

-- ----------------------------------------------------------------------------
-- QUERY 1: Ground Station Downlink Throughput & Signal Quality Analysis
-- Joins ground_stations, antennas, and contact_passes to compute total data
-- volume (GB) and average SNR across completed passes.
-- ----------------------------------------------------------------------------
SELECT 
    gs.station_code,
    gs.facility_name,
    a.rf_band,
    COUNT(cp.pass_id) AS completed_passes,
    ROUND(SUM(cp.downlink_volume_mb) / 1024.0, 2) AS total_downlink_gb,
    ROUND(AVG(cp.avg_snr_db), 2) AS mean_snr_db
FROM ground_stations gs
JOIN antennas a ON gs.station_id = a.station_id
JOIN contact_passes cp ON a.antenna_id = cp.antenna_id
WHERE cp.pass_status = 'COMPLETED'
GROUP BY gs.station_code, gs.facility_name, a.rf_band
ORDER BY total_downlink_gb DESC;

-- ----------------------------------------------------------------------------
-- QUERY 2: Window Function - Top 3 Highest-Volume Passes per Satellite
-- Uses a Common Table Expression (CTE) and DENSE_RANK() window function.
-- ----------------------------------------------------------------------------
WITH RankedPasses AS (
    SELECT 
        s.spacecraft_name,
        s.orbital_regime,
        cp.pass_id,
        cp.aos_timestamp,
        cp.max_elevation_deg,
        cp.downlink_volume_mb,
        DENSE_RANK() OVER (
            PARTITION BY s.satellite_id 
            ORDER BY cp.downlink_volume_mb DESC
        ) AS volume_rank
    FROM contact_passes cp
    JOIN satellites s ON cp.satellite_id = s.satellite_id
    WHERE cp.pass_status = 'COMPLETED'
)
SELECT spacecraft_name, orbital_regime, pass_id, max_elevation_deg, downlink_volume_mb, volume_rank
FROM RankedPasses
WHERE volume_rank <= 2
ORDER BY spacecraft_name, volume_rank;

-- ----------------------------------------------------------------------------
-- QUERY 3: Query Optimisation Benchmark (BEFORE Indexing)
-- Ensure no secondary indexes exist before baseline test
-- ----------------------------------------------------------------------------
DROP INDEX IF EXISTS idx_passes_sat_status_aos;

\echo '=== EXECUTION PLAN BEFORE INDEXING (BASELINE SEQ SCAN) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT pass_id, satellite_id, antenna_id, aos_timestamp, downlink_volume_mb, avg_snr_db
FROM contact_passes
WHERE satellite_id = 2
  AND pass_status = 'COMPLETED'
  AND aos_timestamp BETWEEN '2025-03-01 00:00:00+01' AND '2025-04-15 23:59:59+01'
ORDER BY aos_timestamp DESC;

-- ----------------------------------------------------------------------------
-- APPLY OPTIMISATION: Create Composite B-Tree Index
-- ----------------------------------------------------------------------------
CREATE INDEX idx_passes_sat_status_aos 
ON contact_passes (satellite_id, pass_status, aos_timestamp DESC);

ANALYZE contact_passes;

\echo '=== EXECUTION PLAN AFTER INDEXING (OPTIMISED INDEX SCAN) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT pass_id, satellite_id, antenna_id, aos_timestamp, downlink_volume_mb, avg_snr_db
FROM contact_passes
WHERE satellite_id = 2
  AND pass_status = 'COMPLETED'
  AND aos_timestamp BETWEEN '2025-03-01 00:00:00+01' AND '2025-04-15 23:59:59+01'
ORDER BY aos_timestamp DESC;
