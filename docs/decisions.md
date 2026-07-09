## Schema Design Decisions

### Surrogate keys
Used SERIAL primary keys throughout instead of natural keys.
Rationale: Decouples row identity from changing business data.
Stable references even when emails/names update.

### Soft delete pattern
Added `is_active BOOLEAN` to all dimension tables (customers, suppliers,
workers, products) instead of hard DELETE.
Rationale: Preserves referential integrity for historical orders.
Hard deletes would either fail (FK constraints) or cascade-destroy history.

### Worker dimension table (new)
Created a centralized `workers` table referenced by prep_lists, deliveries,
and worker_shifts via worker_id FK.
Rationale: Original schema used free-text worker names across three tables,
preventing cross-activity analysis and risking data quality issues from
name spelling variations.

### Status enum CHECK constraints
Added CHECK constraints on all status columns (order_status, prep_status,
delivery_status, etc.).
Rationale: VARCHAR alone allows typos like 'Pending' vs 'pending' to corrupt
data. Database-level enforcement is the last line of defense.

### Audit columns
Added created_at and updated_at TIMESTAMP columns to every table.
Rationale: Production standard for tracking data lineage and debugging.

### market_type allowed values
Added 'individual' and 'other' to allowed values.
Rationale: NULL would hide the business category of individual buyers.
Explicit enums keep aggregation queries reliable.

### Inventory grain
Grain: one row per (product_id, inventory_date, warehouse_location).
Enforced via UNIQUE constraint.
Rationale: Prevention beats cleanup. Database-level grain enforcement
prevents duplicate inserts and keeps downstream queries simple.

### DECIMAL for money
Used DECIMAL(10,2) for all monetary columns instead of FLOAT.
Rationale: FLOAT introduces rounding errors unacceptable for money.

### One delivery per order (MVP simplification)
Enforced UNIQUE constraint on deliveries.order_id.
Rationale: Simplifies analytics for MVP. Production would handle split
deliveries via parent_delivery_id self-reference or order-item-level
delivery tracking.

### Denormalization strategy
Stored total_items and total_value on orders_cleaned (denormalized).
Removed stored total_payment from worker_shifts (computed in queries).
Rationale: Denormalize when calculation is expensive (aggregation across
order_items). Leave computed when calculation is cheap (single-row math).

### Index strategy
Created explicit indexes on:
- All foreign key columns (Postgres doesn't auto-index FKs)
- All date columns (time-series queries are dominant pattern)
- All status columns (heavily filtered in analytics)
- Composite index on (customer_id, order_date DESC) for customer history queries
  

## Data Generation Approach

### Master data seeding via Python scripts

Chose Python + psycopg2 over manual SQL imports because:
- Reproducible and version-controlled
- Handles errors gracefully (skip vs crash)
- Programmatic control over distributions and randomness
- Matches production data engineering practice

### Idempotent seed scripts (ON CONFLICT pattern)

All dimension table scripts use `ON CONFLICT DO UPDATE`:
- Safe to re-run without duplicates
- `xmax = 0` trick distinguishes fresh inserts from conflict updates
- Preserves referential integrity for downstream fact tables
- Explicit `updated_at = CURRENT_TIMESTAMP` because DEFAULT
  only fires on INSERT, not UPDATE

### Domain-specific data over generic Faker

Hand-crafted:
- Product catalog (Chinese-American vegetables)
- Restaurant/grocery name generators (weighted prefix + suffix lists)
- Supplier list (Bay Area produce distribution context)
- Worker names and roles

Generic Faker output would have undermined the project's narrative.
Faker is used only where it adds value: signup dates, individual customer names.

### FK resolution via lookup maps

Products reference suppliers by name in source data (readability),
resolved to IDs via one-time query at script start:

1. Query dimension table: `SELECT id, name FROM suppliers`
2. Build lookup dict: `{name: id for id, name in rows}`
3. For each record: translate name → id before insert
4. Skip records with missing references (log warning, continue)

This pattern will extend to Day 2 fact tables that reference
multiple dimensions (customers, products, workers).

### Configuration via environment variables

Database credentials stored in `.env` file (gitignored), loaded via
`python-dotenv`. Follows 12-factor app methodology — configuration
outside code, no secrets in source control.

### Reproducibility via random seeds

`Faker.seed(42)` and `random.seed(42)` make "random" data deterministic.
Anyone cloning the repo gets identical data. Enables reliable testing
of idempotency (same input → same output).