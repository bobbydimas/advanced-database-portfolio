# Portfolio 2: Query Processing and Optimisation

## 1. Overview & Synthetic Dataset Generation
To evaluate PostgreSQL query execution plans under realistic operational loads, seed_data.sql populates the OrbitLink Ground Station & Satellite Telemetry Network (OGSTN) schema with 65,024 records:
* 6 Satellites across LEO, MEO, and GEO regimes.
* 4 Ground Stations (ABJ-GS01, KAN-GS02, LAG-GS03, JOS-GS04) and 8 RF Antennas.
* 6 Mission Control Operators across shift groups.
* 50,000 Orbital Contact Passes generated via generate_series(1, 50000).
* 15,000 Uplink Command Audit Logs generated via generate_series(1, 15000).

---

## 2. Analytical SQL Queries Implemented
1. Multi-Table Downlink Throughput & Signal Analysis (JOIN + GROUP BY): Aggregates completed passes across ground_stations, antennas, and contact_passes to compute total downlink data volume (in GB) and mean Signal-to-Noise Ratio (avg_snr_db) per RF band.
2. Spacecraft Pass Efficiency Ranking (CTE + Window Function): Uses a Common Table Expression (WITH RankedPasses) and DENSE_RANK() OVER (PARTITION BY satellite_id ORDER BY downlink_volume_mb DESC) to isolate the top-performing telemetry passes per spacecraft.
3. Time-Windowed Pass Retrieval (Optimisation Target): Filters contact_passes by satellite_id = 2, pass_status = 'COMPLETED', and an Acquisition of Signal (aos_timestamp) range between March and April 2025, ordered chronologically descending.

---

## 3. Execution Plan & Performance Analysis (EXPLAIN ANALYZE)

### A. Baseline Execution (Before Indexing)
Without secondary indexes on contact_passes, the PostgreSQL query planner must perform a full-table Sequential Scan (Seq Scan) across all 50,000 rows, evaluate the three filter predicates (satellite_id, pass_status, and aos_timestamp) row-by-row, and execute an explicit Sort (quicksort) node in memory.
* Access Method: Seq Scan on contact_passes + Sort (Sort Key: aos_timestamp DESC)
* Rows Removed by Filter: ~49,700+ rows discarded after disk/buffer read.
* Baseline Execution Time: ~6.50 ms - 12.00 ms (see execution_plan_results.txt for exact buffer read counts).

### B. Optimised Execution (After Composite B-Tree Indexing)
To eliminate both the full-table scan and the post-retrieval sort step, a composite B-Tree index was constructed matching the exact selectivity and ordering of the query:

    CREATE INDEX idx_passes_sat_status_aos 
    ON contact_passes (satellite_id, pass_status, aos_timestamp DESC);

* Access Method: Index Scan using idx_passes_sat_status_aos on contact_passes
* Planning Time: 0.349 ms
* Execution Time: 0.573 ms
* Architectural Justification: Because the leading columns (satellite_id, pass_status) use equality predicates (=) and the trailing column (aos_timestamp DESC) handles both the BETWEEN range scan and the ORDER BY aos_timestamp DESC clause, PostgreSQL traverses the B-Tree leaf pages directly in reverse chronological order. This reduces buffer hits drastically, eliminates the separate Sort node entirely, and achieves sub-millisecond execution (0.573 ms).
