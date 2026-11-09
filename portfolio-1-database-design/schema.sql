-- ============================================================================
-- MIT 8103: Advanced Database Systems - Portfolio 1
-- System: OrbitLink Ground Station & Satellite Telemetry Network (OGSTN)
-- Database Engine: PostgreSQL
-- ============================================================================

DROP TABLE IF EXISTS uplink_commands CASCADE;
DROP TABLE IF EXISTS contact_passes CASCADE;
DROP TABLE IF EXISTS mission_operators CASCADE;
DROP TABLE IF EXISTS antennas CASCADE;
DROP TABLE IF EXISTS ground_stations CASCADE;
DROP TABLE IF EXISTS satellites CASCADE;

-- 1. SATELLITES REGISTRY
CREATE TABLE satellites (
    satellite_id SERIAL PRIMARY KEY,
    norad_catalog_no VARCHAR(12) UNIQUE NOT NULL,
    spacecraft_name VARCHAR(80) UNIQUE NOT NULL,
    orbital_regime VARCHAR(10) NOT NULL CHECK (orbital_regime IN ('LEO', 'MEO', 'GEO', 'HEO')),
    inclination_deg NUMERIC(5,2) NOT NULL CHECK (inclination_deg BETWEEN 0.00 AND 180.00),
    launch_date DATE NOT NULL,
    operational_state VARCHAR(20) NOT NULL DEFAULT 'NOMINAL'
        CHECK (operational_state IN ('NOMINAL', 'SAFE_MODE', 'COMMISSIONING', 'DECOMMISSIONED'))
);

-- 2. GROUND STATIONS
CREATE TABLE ground_stations (
    station_id SERIAL PRIMARY KEY,
    station_code VARCHAR(10) UNIQUE NOT NULL,
    facility_name VARCHAR(100) NOT NULL,
    region_location VARCHAR(80) NOT NULL,
    latitude_deg NUMERIC(8,5) NOT NULL CHECK (latitude_deg BETWEEN -90.00000 AND 90.00000),
    longitude_deg NUMERIC(8,5) NOT NULL CHECK (longitude_deg BETWEEN -180.00000 AND 180.00000),
    altitude_m INTEGER NOT NULL CHECK (altitude_m >= -500)
);

-- 3. RF ANTENNAS
CREATE TABLE antennas (
    antenna_id SERIAL PRIMARY KEY,
    station_id INTEGER NOT NULL REFERENCES ground_stations(station_id) ON DELETE RESTRICT,
    antenna_designator VARCHAR(20) UNIQUE NOT NULL,
    rf_band VARCHAR(15) NOT NULL CHECK (rf_band IN ('S-Band', 'X-Band', 'Ka-Band', 'UHF')),
    dish_diameter_m NUMERIC(4,1) NOT NULL CHECK (dish_diameter_m > 0.5),
    max_slew_rate_deg_sec NUMERIC(4,2) NOT NULL CHECK (max_slew_rate_deg_sec > 0),
    maintenance_status VARCHAR(20) NOT NULL DEFAULT 'ONLINE'
        CHECK (maintenance_status IN ('ONLINE', 'CALIBRATING', 'FAULT', 'OFFLINE'))
);

-- 4. MISSION CONTROL OPERATORS
CREATE TABLE mission_operators (
    operator_id SERIAL PRIMARY KEY,
    badge_number VARCHAR(15) UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    clearance_level VARCHAR(15) NOT NULL CHECK (clearance_level IN ('LEVEL_1', 'LEVEL_2', 'FLIGHT_DIRECTOR')),
    shift_group VARCHAR(15) NOT NULL CHECK (shift_group IN ('ALPHA', 'BRAVO', 'CHARLIE', 'DELTA')),
    active_duty BOOLEAN NOT NULL DEFAULT TRUE
);

-- 5. ORBITAL CONTACT PASSES
CREATE TABLE contact_passes (
    pass_id BIGSERIAL PRIMARY KEY,
    satellite_id INTEGER NOT NULL REFERENCES satellites(satellite_id) ON DELETE RESTRICT,
    antenna_id INTEGER NOT NULL REFERENCES antennas(antenna_id) ON DELETE RESTRICT,
    lead_operator_id INTEGER NOT NULL REFERENCES mission_operators(operator_id) ON DELETE RESTRICT,
    aos_timestamp TIMESTAMPTZ NOT NULL,
    los_timestamp TIMESTAMPTZ NOT NULL,
    max_elevation_deg NUMERIC(4,1) NOT NULL CHECK (max_elevation_deg BETWEEN 5.0 AND 90.0),
    avg_snr_db NUMERIC(5,2),
    downlink_volume_mb NUMERIC(10,2) NOT NULL DEFAULT 0.00 CHECK (downlink_volume_mb >= 0.00),
    pass_status VARCHAR(20) NOT NULL DEFAULT 'SCHEDULED'
        CHECK (pass_status IN ('SCHEDULED', 'ACTIVE', 'COMPLETED', 'ABORTED')),
    CONSTRAINT chk_valid_pass_window CHECK (los_timestamp > aos_timestamp)
);

-- 6. UPLINK COMMAND AUDIT LOGS
CREATE TABLE uplink_commands (
    command_id BIGSERIAL PRIMARY KEY,
    pass_id BIGINT NOT NULL REFERENCES contact_passes(pass_id) ON DELETE CASCADE,
    issued_by_operator_id INTEGER NOT NULL REFERENCES mission_operators(operator_id) ON DELETE RESTRICT,
    command_opcode VARCHAR(25) NOT NULL,
    payload_hex VARCHAR(256) NOT NULL,
    transmitted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ack_received BOOLEAN NOT NULL DEFAULT FALSE,
    execution_state VARCHAR(20) NOT NULL DEFAULT 'QUEUED'
        CHECK (execution_state IN ('QUEUED', 'TRANSMITTED', 'EXECUTED', 'REJECTED', 'TIMEOUT'))
);
