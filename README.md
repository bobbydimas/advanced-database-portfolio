# MIT 8103: Advanced Database Systems Portfolio

* **Institution:** Miva Open University — School of Postgraduate Studies
* **Programme:** Master of Information Technology (2026/2027 Academic Session)
* **Course:** MIT 8103 Advanced Database Systems
* **Selected Case Study:** OrbitLink Ground Station & Satellite Telemetry Network (OGSTN)
* **Database Engines Used:** PostgreSQL 16 (Relational, ACID Transactions, Declarative Sharding, JSONB/GIN Document Store) & MongoDB (Document Aggregation Pipeline)

---

## Repository Structure

* **portfolio-1-database-design/** — Case study specification, 3NF normalisation proof, Crow's Foot ER model (er_diagram.dbml / er_diagram.png), PostgreSQL DDL script (schema.sql), and schema verification screenshot.
* **portfolio-2-query-optimisation/** — 65,000+ record synthetic data generator (seed_data.sql), analytical JOIN/CTE/Window queries, composite B-Tree index tuning (queries_and_optimisation.sql), and EXPLAIN ANALYZE performance logs (0.573 ms indexed execution).
* **portfolio-3-transactions-concurrency/** — ACID transaction scripts demonstrating COMMIT, SAVEPOINT partial recovery, full ROLLBACK, REPEATABLE READ isolation, and pessimistic row locking via SELECT ... FOR UPDATE NOWAIT.
* **portfolio-4-nosql/** — Hierarchical satellite telemetry document models implemented in both MongoDB (telemetry_nosql.mongodb.js) and PostgreSQL JSONB with GIN indexing (nosql_telemetry_documents.sql), plus containment and aggregation outputs.
* **portfolio-5-distributed-cloud/** — Geo-distributed horizontal sharding across four regional ground station nodes (distributed_sharding_setup.sql), partition pruning verification, replication topology, and CAP/PACELC analysis.

---

## How to Reproduce & Verify All Scripts Locally (macOS / Linux)

1. Create the database and initialise the 3NF schema:
   createdb orbitlink_db
   psql -d orbitlink_db -f portfolio-1-database-design/schema.sql

2. Seed 65,000+ rows and run query optimisation benchmarks:
   psql -d orbitlink_db -f portfolio-2-query-optimisation/seed_data.sql
   psql -d orbitlink_db -f portfolio-2-query-optimisation/queries_and_optimisation.sql

3. Execute ACID transactions and concurrency locking tests:
   psql -d orbitlink_db -f portfolio-3-transactions-concurrency/transactions_and_concurrency.sql

4. Run NoSQL document store indexing and hierarchical aggregations:
   psql -d orbitlink_db -f portfolio-4-nosql/nosql_telemetry_documents.sql

5. Run distributed regional sharding and partition pruning verification:
   psql -d orbitlink_db -f portfolio-5-distributed-cloud/distributed_sharding_setup.sql
