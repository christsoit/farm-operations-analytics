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