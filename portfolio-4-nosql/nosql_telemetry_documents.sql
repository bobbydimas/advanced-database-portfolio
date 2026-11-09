-- ============================================================================
-- MIT 8103: Advanced Database Systems - Portfolio 4
-- NoSQL Document & Key-Value Data Model (PostgreSQL JSONB + GIN Indexing)
-- System: OrbitLink Ground Station & Satellite Telemetry Network (OGSTN)
-- ============================================================================

DROP TABLE IF EXISTS downlink_telemetry_docs CASCADE;

-- 1. Create Schema-less NoSQL Document Collection Table
-- Stores variable-structure, deeply nested spacecraft telemetry payloads (JSONB)
-- alongside a Key-Value subsystem tag map.
CREATE TABLE downlink_telemetry_docs (
    doc_id BIGSERIAL PRIMARY KEY,
    frame_uuid VARCHAR(30) UNIQUE NOT NULL,
    pass_id BIGINT REFERENCES contact_passes(pass_id) ON DELETE SET NULL,
    captured_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    telemetry_document JSONB NOT NULL
);

-- 2. Create a Generalized Inverted Index (GIN) on the NoSQL Document Payload
-- Allows high-speed indexing into arbitrary nested keys and arrays inside JSONB
CREATE INDEX idx_gin_telemetry_doc ON downlink_telemetry_docs USING GIN (telemetry_document);

-- 3. Insert Hierarchical NoSQL Documents (Nested Objects & Arrays)
INSERT INTO downlink_telemetry_docs (frame_uuid, pass_id, captured_at, telemetry_document) VALUES
(
    'FRM-20261109-0001',
    50001,
    '2026-11-09 14:02:10+01',
    '{
        "norad_catalog_no": "NORAD-51044",
        "spacecraft_name": "ORBITLINK-SAR-1",
        "station_code": "ABJ-GS01",
        "rf_metrics": {
            "band": "X-Band",
            "carrier_freq_ghz": 8.24,
            "snr_db": 19.4,
            "doppler_shift_khz": -42.8
        },
        "eps_subsystem": {
            "bus_voltage_v": 28.4,
            "battery_soc_pct": 91.2,
            "battery_temp_c": 22.5,
            "solar_strings": [
                {"panel_id": "SA-PORT", "current_a": 4.8, "temp_c": 41.2},
                {"panel_id": "SA-STBD", "current_a": 4.7, "temp_c": 40.9}
            ]
        },
        "adcs_subsystem": {
            "mode": "NADIR_POINTING",
            "quaternion": [0.7071, 0.0012, -0.7070, 0.0004],
            "reaction_wheels_rpm": [1420, -980, 2110, 450]
        },
        "active_alerts": []
    }'::jsonb
),
(
    'FRM-20261109-0002',
    50001,
    '2026-11-09 14:05:40+01',
    '{
        "norad_catalog_no": "NORAD-51044",
        "spacecraft_name": "ORBITLINK-SAR-1",
        "station_code": "ABJ-GS01",
        "rf_metrics": {
            "band": "X-Band",
            "carrier_freq_ghz": 8.24,
            "snr_db": 21.8,
            "doppler_shift_khz": -5.1
        },
        "eps_subsystem": {
            "bus_voltage_v": 27.9,
            "battery_soc_pct": 88.5,
            "battery_temp_c": 36.8,
            "solar_strings": [
                {"panel_id": "SA-PORT", "current_a": 5.1, "temp_c": 58.4},
                {"panel_id": "SA-STBD", "current_a": 4.9, "temp_c": 54.0}
            ]
        },
        "adcs_subsystem": {
            "mode": "SAR_SLEW_TARGET",
            "quaternion": [0.6810, 0.1920, -0.6805, 0.1915],
            "reaction_wheels_rpm": [3890, -2410, 4120, 1100]
        },
        "active_alerts": [
            {"severity": "WARNING", "code": "THERM_BATT_HIGH", "message": "Battery pack exceeded 35C during SAR burst"}
        ]
    }'::jsonb
),
(
    'FRM-20261109-0003',
    49988,
    '2026-11-09 15:10:00+01',
    '{
        "norad_catalog_no": "NORAD-52310",
        "spacecraft_name": "AERO-METEO-4",
        "station_code": "JOS-GS04",
        "rf_metrics": {
            "band": "S-Band",
            "carrier_freq_ghz": 2.25,
            "snr_db": 11.2,
            "doppler_shift_khz": 18.4
        },
        "eps_subsystem": {
            "bus_voltage_v": 24.1,
            "battery_soc_pct": 42.0,
            "battery_temp_c": 39.2,
            "solar_strings": [
                {"panel_id": "SA-MAIN", "current_a": 1.2, "temp_c": 19.5}
            ]
        },
        "adcs_subsystem": {
            "mode": "SUN_SAFE_HOLD",
            "quaternion": [1.0, 0.0, 0.0, 0.0],
            "reaction_wheels_rpm": [0, 120, -90, 0]
        },
        "active_alerts": [
            {"severity": "CRITICAL", "code": "EPS_UNDERVOLT", "message": "Main bus voltage dropped below 25.0V"},
            {"severity": "WARNING", "code": "THERM_BATT_HIGH", "message": "Battery thermal anomaly detected"}
        ]
    }'::jsonb
);

-- 4. NoSQL Document Containment Query (@> operator using GIN Index)
-- Find all telemetry frames containing a THERM_BATT_HIGH alert inside the nested active_alerts array
\echo '=== NOSQL QUERY 1: DOCUMENT CONTAINMENT SEARCH (@> OPERATOR) ==='
SELECT 
    frame_uuid,
    telemetry_document->>'spacecraft_name' AS spacecraft,
    telemetry_document->'eps_subsystem'->>'battery_temp_c' AS battery_temp_c,
    jsonb_pretty(telemetry_document->'active_alerts') AS triggered_alerts
FROM downlink_telemetry_docs
WHERE telemetry_document @> '{"active_alerts": [{"code": "THERM_BATT_HIGH"}]}';

-- 5. NoSQL Hierarchical Aggregation Pipeline (Unnesting Solar Array Strings)
\echo '=== NOSQL QUERY 2: AGGREGATING NESTED TELEMETRY SUB-DOCUMENTS ==='
SELECT 
    telemetry_document->>'spacecraft_name' AS spacecraft,
    telemetry_document->>'norad_catalog_no' AS norad_id,
    COUNT(doc_id) AS frames_captured,
    ROUND(AVG((telemetry_document->'eps_subsystem'->>'battery_temp_c')::numeric), 2) AS avg_batt_temp_c,
    MAX((telemetry_document->'rf_metrics'->>'snr_db')::numeric) AS peak_snr_db,
    MIN((telemetry_document->'eps_subsystem'->>'battery_soc_pct')::numeric) AS min_soc_pct
FROM downlink_telemetry_docs
GROUP BY 
    telemetry_document->>'spacecraft_name',
    telemetry_document->>'norad_catalog_no'
ORDER BY avg_batt_temp_c DESC;
