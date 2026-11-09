-- ============================================================================
-- MIT 8103: Advanced Database Systems - Portfolio 2
-- High-Volume Synthetic Telemetry & Pass Seeding Script (65,000+ Records)
-- ============================================================================

TRUNCATE uplink_commands, contact_passes, mission_operators, antennas, ground_stations, satellites RESTART IDENTITY CASCADE;

-- 1. Insert Satellites
INSERT INTO satellites (norad_catalog_no, spacecraft_name, orbital_regime, inclination_deg, launch_date, operational_state) VALUES
('NORAD-49201', 'NIGCOMSAT-2R', 'GEO', 0.05, '2023-04-12', 'NOMINAL'),
('NORAD-51044', 'ORBITLINK-SAR-1', 'LEO', 97.42, '2024-01-19', 'NOMINAL'),
('NORAD-51882', 'ORBITLINK-OPT-2', 'LEO', 53.15, '2024-06-03', 'NOMINAL'),
('NORAD-52310', 'AERO-METEO-4', 'MEO', 64.80, '2024-11-28', 'SAFE_MODE'),
('NORAD-53009', 'SAHEL-WATCH-1', 'LEO', 98.10, '2025-02-14', 'NOMINAL'),
('NORAD-53991', 'ECOWAS-RELAY-3', 'GEO', 0.12, '2025-08-22', 'COMMISSIONING');

-- 2. Insert Ground Stations
INSERT INTO ground_stations (station_code, facility_name, region_location, latitude_deg, longitude_deg, altitude_m) VALUES
('ABJ-GS01', 'Lugbe Space Tracking Complex', 'Abuja, FCT', 8.98640, 7.36210, 476),
('KAN-GS02', 'Kano Northern Telemetry Array', 'Kano State', 12.00220, 8.59200, 488),
('LAG-GS03', 'Epe Coastal Downlink Facility', 'Lagos State', 6.58410, 3.98330, 15),
('JOS-GS04', 'Plateau High-Altitude Deep Space Dish', 'Plateau State', 9.89650, 8.85830, 1217);

-- 3. Insert RF Antennas
INSERT INTO antennas (station_id, antenna_designator, rf_band, dish_diameter_m, max_slew_rate_deg_sec, maintenance_status) VALUES
(1, 'ABJ-X01', 'X-Band', 7.3, 3.50, 'ONLINE'),
(1, 'ABJ-KA02', 'Ka-Band', 5.4, 4.20, 'ONLINE'),
(1, 'ABJ-S03', 'S-Band', 9.0, 2.10, 'CALIBRATING'),
(2, 'KAN-X01', 'X-Band', 7.3, 3.50, 'ONLINE'),
(2, 'KAN-UHF02', 'UHF', 3.2, 6.00, 'ONLINE'),
(3, 'LAG-KA01', 'Ka-Band', 6.1, 4.00, 'ONLINE'),
(4, 'JOS-X01', 'X-Band', 11.2, 1.80, 'ONLINE'),
(4, 'JOS-S02', 'S-Band', 8.5, 2.50, 'ONLINE');

-- 4. Insert Mission Control Operators
INSERT INTO mission_operators (badge_number, full_name, clearance_level, shift_group, active_duty) VALUES
('OP-1001', 'Engr. Ibrahim Danjuma', 'FLIGHT_DIRECTOR', 'ALPHA', TRUE),
('OP-1002', 'Chidinma Okafor', 'LEVEL_2', 'ALPHA', TRUE),
('OP-1003', 'Tunde Bakare', 'LEVEL_2', 'BRAVO', TRUE),
('OP-1004', 'Amina Yusuf', 'LEVEL_1', 'CHARLIE', TRUE),
('OP-1005', 'Kelechi Nwosu', 'FLIGHT_DIRECTOR', 'DELTA', TRUE),
('OP-1006', 'Fatima Bello', 'LEVEL_2', 'BRAVO', TRUE);

-- 5. Generate 50,000 Realistic Orbital Contact Passes
INSERT INTO contact_passes (
    satellite_id, antenna_id, lead_operator_id,
    aos_timestamp, los_timestamp,
    max_elevation_deg, avg_snr_db, downlink_volume_mb, pass_status
)
SELECT
    (floor(random() * 6) + 1)::int AS satellite_id,
    (floor(random() * 8) + 1)::int AS antenna_id,
    (floor(random() * 6) + 1)::int AS lead_operator_id,
    TIMESTAMPTZ '2025-01-01 00:00:00+01' + (g * INTERVAL '15 minutes') AS aos_timestamp,
    TIMESTAMPTZ '2025-01-01 00:00:00+01' + (g * INTERVAL '15 minutes') + INTERVAL '11 minutes' AS los_timestamp,
    round((10.0 + random() * 75.0)::numeric, 1) AS max_elevation_deg,
    round((8.5 + random() * 24.0)::numeric, 2) AS avg_snr_db,
    round((150.0 + random() * 4850.0)::numeric, 2) AS downlink_volume_mb,
    (ARRAY['COMPLETED', 'COMPLETED', 'COMPLETED', 'SCHEDULED', 'ABORTED'])[floor(random() * 5) + 1] AS pass_status
FROM generate_series(1, 50000) AS g;

-- 6. Generate 15,000 Uplink Command Audit Logs
INSERT INTO uplink_commands (
    pass_id, issued_by_operator_id, command_opcode,
    payload_hex, transmitted_at, ack_received, execution_state
)
SELECT
    (floor(random() * 50000) + 1)::bigint AS pass_id,
    (floor(random() * 6) + 1)::int AS issued_by_operator_id,
    (ARRAY['ATTITUDE_SLEW', 'PAYLOAD_IMG_START', 'TX_POWER_HIGH', 'SOLAR_ARRAY_TRIM', 'WATCHDOG_RESET'])[floor(random() * 5) + 1] AS command_opcode,
    upper(md5(random()::text)) AS payload_hex,
    TIMESTAMPTZ '2025-01-01 00:05:00+01' + (g * INTERVAL '45 minutes') AS transmitted_at,
    (random() > 0.08) AS ack_received,
    (ARRAY['EXECUTED', 'EXECUTED', 'EXECUTED', 'TIMEOUT', 'REJECTED'])[floor(random() * 5) + 1] AS execution_state
FROM generate_series(1, 15000) AS g;

-- Update PostgreSQL planner statistics
ANALYZE;
