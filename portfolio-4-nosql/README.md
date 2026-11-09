# Portfolio 4: NoSQL and Advanced Data Models

## 1. Suitability of the Document Data Model for Satellite Telemetry
While the relational model (Portfolios 1-3) enforces strict 3NF integrity for orbital pass schedules, ground station hardware, and operator clearances, raw spacecraft downlink streams exhibit three characteristics that make rigid relational tables inefficient:
1. Schema Polymorphism Across Spacecraft Generations: A Synthetic Aperture Radar (SAR) satellite (ORBITLINK-SAR-1) transmits dual solar-string arrays and 4-wheel reaction telemetry, whereas a meteorological platform (AERO-METEO-4) transmits single-bus payload sensors and varying fault structures.
2. Deeply Nested Hierarchical Payloads: Each downlink frame encapsulates RF metrics, Electrical Power Subsystem (EPS) arrays, Attitude Determination and Control Subsystem (ADCS) quaternions, and variable-length alert arrays within a single logical packet.
3. High Ingestion Velocity & Self-Contained Reads: Storing each frame as an atomic document eliminates expensive 5-way relational joins when Mission Control dashboards query real-time spacecraft health.

---

## 2. Dual NoSQL Implementation Evidence
This portfolio provides two complementary implementations of the OrbitLink telemetry document model:
1. Native MongoDB BSON Collection & Aggregation Pipeline (telemetry_nosql.mongodb.js): Defines the downlink_frames collection, compound index ({ norad_catalog_no: 1, captured_at: -1 }), nested array filtering, and a multi-stage $group and $sort aggregation pipeline.
2. Multi-Model Binary JSON Document Store (nosql_telemetry_documents.sql): Implements the downlink_telemetry_docs collection using PostgreSQL JSONB with a Generalized Inverted Index (GIN) on telemetry_document. This enables hybrid relational-to-document linking (via pass_id) alongside native JSONB containment queries (@>) and sub-document aggregation.

---

## 3. Indexing & Query Evaluation
* GIN Indexing on Document Trees: Creating idx_gin_telemetry_doc USING GIN (telemetry_document) indexes every nested key and value path inside the binary JSON structure.
* Sub-Document Containment Search: Using the @> containment operator rapidly isolates frames containing {"active_alerts": [{"code": "THERM_BATT_HIGH"}]} without scanning unindexed text blobs.
* Hierarchical Aggregation: Extracts nested numeric paths (eps_subsystem.battery_temp_c and rf_metrics.snr_db) to compute thermal averages and peak signal metrics per spacecraft.
