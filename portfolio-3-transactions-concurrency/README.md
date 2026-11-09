# Portfolio 3: Transactions and Concurrency Control

## 1. ACID Transaction Management in OrbitLink (OGSTN)
In a satellite ground station network, scheduling an orbital contact pass and queuing command uplinks must execute as atomic, isolated units of work. Partial execution or concurrent race conditions could result in conflicting dish slew commands or unlogged spacecraft transmissions.

### Scenario 1: Atomic Pass Scheduling & Command Queuing (COMMIT)
* Mechanism: Explicit transaction block (BEGIN ... COMMIT) at READ COMMITTED isolation.
* Operational Flow:
  1. Acquires an exclusive row lock (SELECT ... FOR UPDATE) on Antenna ABJ-X01 (antenna_id = 1) to verify its maintenance state is ONLINE.
  2. Inserts a new contact pass record into contact_passes.
  3. Queues a PAYLOAD_SAR_CALIBRATE hex command into uplink_commands referencing the newly generated pass_id via currval('contact_passes_pass_id_seq').
  4. Executes COMMIT, making both the schedule and command audit log durable simultaneously.

### Scenario 2: Constraint Violation Recovery via Partial Rollback (SAVEPOINT)
* Mechanism: SAVEPOINT sp_after_antenna_online and ROLLBACK TO SAVEPOINT.
* Operational Flow:
  1. Updates Antenna ABJ-S03 (antenna_id = 3) from CALIBRATING to ONLINE.
  2. Establishes a savepoint (sp_after_antenna_online).
  3. Attempts to insert a malformed contact pass where Loss of Signal (18:15 UTC) occurs earlier than Acquisition of Signal (18:30 UTC), triggering the relational constraint chk_valid_pass_window.
  4. Executes ROLLBACK TO SAVEPOINT sp_after_antenna_online, discarding the invalid pass entry while preserving and committing the valid antenna status transition.

### Scenario 3: Emergency Override Abort (Full ROLLBACK)
* Mechanism: Full transaction abort (ROLLBACK).
* Operational Flow: Simulates an uncommitted transition of satellite NIGCOMSAT-2R (satellite_id = 1) into SAFE_MODE. Invoking ROLLBACK immediately restores the tuple to its pre-transaction NOMINAL state, proving transaction atomicity and durability rules.

---

## 2. Concurrency Control & Isolation Analysis

### Concurrency Hazard: Lost Updates & Antenna Double-Booking
If two Mission Control Operators simultaneously query Antenna ABJ-KA02 (antenna_id = 2), see that it is available, and concurrently update pass telemetry or book overlapping windows, a Lost Update or Phantom Write anomaly occurs.

### Implemented Control Mechanism (REPEATABLE READ + SELECT FOR UPDATE NOWAIT)
* Isolation Level: BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ guarantees that snapshot reads within the transaction remain consistent and prevents non-repeatable reads.
* Pessimistic Row-Level Locking: Executing SELECT ... FROM antennas WHERE antenna_id = 2 FOR UPDATE NOWAIT places an exclusive write lock on that specific antenna tuple without blocking the entire table.
* Fail-Fast Contention Handling: Adding the NOWAIT directive ensures that if a second operator's transaction attempts to lock the same antenna concurrently, PostgreSQL immediately aborts the conflicting request with lock_not_available rather than stalling the mission control telemetry pipeline in a deadlock queue.
