-- ============================================================================
-- MIT 8103: Advanced Database Systems - Portfolio 3
-- ACID Transactions (COMMIT, SAVEPOINT, ROLLBACK) & Concurrency Control
-- ============================================================================

-- ============================================================================
-- SCENARIO 1: ATOMIC TRANSACTION WITH COMMIT
-- An operator schedules an urgent orbital pass on Antenna ABJ-X01 (antenna_id = 1)
-- and queues an attitude-control command uplink in a single atomic unit of work.
-- ============================================================================
\echo '=== SCENARIO 1: ATOMIC PASS SCHEDULING & COMMAND QUEUING (COMMIT) ==='

BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Step 1A: Lock the target antenna row to verify it is ONLINE before scheduling
SELECT antenna_id, antenna_designator, maintenance_status
FROM antennas
WHERE antenna_id = 1
FOR UPDATE;

-- Step 1B: Insert the new scheduled contact pass
INSERT INTO contact_passes (
    satellite_id, antenna_id, lead_operator_id,
    aos_timestamp, los_timestamp,
    max_elevation_deg, avg_snr_db, downlink_volume_mb, pass_status
) VALUES (
    2, 1, 1,
    '2026-11-15 14:00:00+01', '2026-11-15 14:12:00+01',
    68.5, NULL, 0.00, 'SCHEDULED'
);

-- Step 1C: Queue an encrypted telemetry command for the newly created pass
INSERT INTO uplink_commands (
    pass_id, issued_by_operator_id, command_opcode,
    payload_hex, ack_received, execution_state
) VALUES (
    currval('contact_passes_pass_id_seq'), 1, 'PAYLOAD_SAR_CALIBRATE',
    '4F524249544C494E4B5F5341525F43414C5F3031', FALSE, 'QUEUED'
);

COMMIT;

-- Verify the committed records exist
SELECT cp.pass_id, cp.aos_timestamp, cp.pass_status, uc.command_opcode, uc.execution_state
FROM contact_passes cp
JOIN uplink_commands uc ON cp.pass_id = uc.pass_id
WHERE cp.aos_timestamp = '2026-11-15 14:00:00+01';


-- ============================================================================
-- SCENARIO 2: PARTIAL ROLLBACK USING SAVEPOINT (CONSTRAINT VIOLATION RECOVERY)
-- During an active pass update, an invalid temporal window (LOS < AOS) is
-- attempted. The transaction rolls back to a SAVEPOINT without losing the
-- valid antenna status update.
-- ============================================================================
\echo '=== SCENARIO 2: SAVEPOINT & ROLLBACK RECOVERY ==='

BEGIN;

-- Valid operation: Transition Antenna ABJ-S03 (antenna_id = 3) from CALIBRATING to ONLINE
UPDATE antennas
SET maintenance_status = 'ONLINE'
WHERE antenna_id = 3;

SAVEPOINT sp_after_antenna_online;

-- Invalid operation: Attempt to insert a corrupted pass where LOS timestamp is earlier than AOS
-- This intentionally triggers chk_valid_pass_window (los_timestamp > aos_timestamp)
INSERT INTO contact_passes (
    satellite_id, antenna_id, lead_operator_id,
    aos_timestamp, los_timestamp,
    max_elevation_deg, pass_status
) VALUES (
    1, 3, 2,
    '2026-11-16 18:30:00+01', '2026-11-16 18:15:00+01', -- INVALID WINDOW!
    45.0, 'SCHEDULED'
);

-- Recover from constraint failure by rolling back to the savepoint
ROLLBACK TO SAVEPOINT sp_after_antenna_online;

-- Commit the valid antenna state change
COMMIT;

-- Verify Antenna 3 is now ONLINE while the invalid pass was cleanly aborted
SELECT antenna_id, antenna_designator, maintenance_status
FROM antennas
WHERE antenna_id = 3;


-- ============================================================================
-- SCENARIO 3: FULL TRANSACTION ROLLBACK (EMERGENCY ABORT)
-- Simulates aborting an unauthorised command uplink batch before commit.
-- ============================================================================
\echo '=== SCENARIO 3: FULL ATOMIC ROLLBACK ==='

BEGIN;

UPDATE satellites
SET operational_state = 'SAFE_MODE'
WHERE satellite_id = 1;

\echo 'State inside uncommitted transaction:'
SELECT satellite_id, spacecraft_name, operational_state FROM satellites WHERE satellite_id = 1;

-- Operator aborts the emergency override; rollback restores original state
ROLLBACK;

\echo 'State after ROLLBACK (restored to NOMINAL):'
SELECT satellite_id, spacecraft_name, operational_state FROM satellites WHERE satellite_id = 1;


-- ============================================================================
-- SCENARIO 4: REPEATABLE READ ISOLATION & PESSIMISTIC ROW LOCKING (NOWAIT)
-- Prevents Lost Updates and Double-Booking of Ground Station Antennas.
-- ============================================================================
\echo '=== SCENARIO 4: REPEATABLE READ & PESSIMISTIC LOCKING ==='

BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Acquire an exclusive row-level lock on Antenna 2 (ABJ-KA02) with NOWAIT
-- Any concurrent session attempting SELECT ... FOR UPDATE NOWAIT on antenna_id = 2
-- will immediately fail with ERROR: could not obtain lock on row in relation "antennas"
SELECT antenna_id, antenna_designator, rf_band, maintenance_status
FROM antennas
WHERE antenna_id = 2
FOR UPDATE NOWAIT;

UPDATE contact_passes
SET pass_status = 'COMPLETED',
    downlink_volume_mb = downlink_volume_mb + 512.40
WHERE pass_id = 50001;

COMMIT;

SELECT pass_id, antenna_id, pass_status, downlink_volume_mb
FROM contact_passes
WHERE pass_id = 50001;
