# Portfolio 1: Database Design and Modelling

## 1. Case Study Statement: OrbitLink Ground Station & Satellite Telemetry Network (OGSTN)
* **Organisation / System Name:** OrbitLink Ground Station & Satellite Telemetry Network (OGSTN)
* **Nature of the System:** Mission-critical aerospace infrastructure platform that manages Low-Earth Orbit (LEO) and Geostationary (GEO) satellites, regional ground station antennas, orbital pass scheduling, command uplink authorization, and raw telemetry downlink cataloguing.
* **Primary Database Users:**
  * **Flight Dynamics Engineers:** Schedule orbital contact windows (passes) and allocate ground station antennas.
  * **Mission Control Operators:** Issue encrypted command uplinks and monitor real-time subsystem health during passes.
  * **Network Administrators:** Manage ground station antenna maintenance states and RF transceiver availability.
  * **Automated Ingestion Gateways:** Write pass telemetry metrics and command execution statuses directly to the database.
* **Major Data Stored:** Registered satellites, orbital parameters, ground station facilities, RF transceiver antennas, operator clearance profiles, scheduled contact passes, and command uplink audit logs.
* **Key Database Operations Supported:**
  1. Registering spacecraft and assigning orbital regime classifications.
  2. Allocating specific ground station antennas to satellite pass windows without time-slot collisions.
  3. Logging and auditing command uplinks transmitted during active contact windows.
  4. Tracking downlink data volume and signal-to-noise ratio (SNR) across completed passes.

---

## 2. Relational Schema & Constraints Summary
The relational model consists of six core entities implemented in PostgreSQL:
1. `satellites` — Stores spacecraft registry, NORAD catalog IDs, orbital regimes (`LEO`, `MEO`, `GEO`), and operational status.
2. `ground_stations` — Stores physical tracking facilities, geodetic coordinates, and elevation metrics.
3. `antennas` — Stores parabolic dish receivers linked to a specific `ground_station` via Foreign Key, tracking frequency band (`S-Band`, `X-Band`, `Ka-Band`), aperture diameter, and operational status.
4. `mission_operators` — Stores certified flight controllers, clearance tiers, and unique badge credentials.
5. `contact_passes` — Core scheduling entity linking `satellites`, `antennas`, and `mission_operators` over an Acquisition of Signal (`aos_timestamp`) and Loss of Signal (`los_timestamp`) window.
6. `uplink_commands` — Transactional audit log of hex command payloads transmitted during a specific `contact_pass`.

---

## 3. Normalisation Justification (1NF to 3NF)

### First Normal Form (1NF)
* **Rule:** Eliminate repeating groups and ensure all attributes hold atomic values.
* **Application in OGSTN:** In an unnormalised spreadsheet, a single `ground_station` row might store multiple dish configurations in a comma-separated column (e.g., `antennas = "Dish-1 (X-Band), Dish-2 (S-Band)"`), or a `contact_pass` row might store an array of transmitted commands. To satisfy 1NF, multi-valued dish records were separated into the `antennas` table, and individual command transmissions were isolated into `uplink_commands`, ensuring every column contains a single atomic attribute.

### Second Normal Form (2NF)
* **Rule:** Satisfy 1NF and eliminate partial functional dependencies (where non-key attributes depend on only part of a composite primary key).
* **Application in OGSTN:** During initial modelling of pass scheduling, a composite key of `(satellite_id, antenna_id, aos_timestamp)` was considered alongside attributes like `satellite_norad_id` and `antenna_freq_band`. Because `satellite_norad_id` depends solely on `satellite_id` and `antenna_freq_band` depends solely on `antenna_id`, keeping them in the schedule table would create partial dependencies and update anomalies. By assigning surrogate/atomic primary keys (`pass_id`, `satellite_id`, `antenna_id`) and moving spacecraft and hardware attributes into `satellites` and `antennas`, every non-key attribute in `contact_passes` (`aos_timestamp`, `los_timestamp`, `max_elevation_deg`, `downlink_volume_mb`) is fully functionally dependent on `pass_id`.

### Third Normal Form (3NF)
* **Rule:** Satisfy 2NF and eliminate transitive functional dependencies (where a non-key attribute depends on another non-key attribute).
* **Application in OGSTN:** In the `antennas` table, storing the facility's city, latitude, and longitude alongside `station_id` would introduce a transitive dependency: `antenna_id -> station_id -> (station_name, latitude, longitude)`. If a ground station's coordinates were updated, multiple rows in `antennas` would require modification. To achieve strict 3NF, all facility location attributes were isolated into the `ground_stations` table, leaving `station_id` as a Foreign Key inside `antennas`.
