### Surrogate keys
Used SERIAL primary keys throughout instead of natural keys.
Rationale: Decouples row identity from changing business data. Stable
references even when emails/names update.

### Soft delete pattern
Added `is_active BOOLEAN` to all dimension tables (customers, suppliers,
workers, products) instead of hard DELETE.
Rationale: Preserves referential integrity for historical orders. Hard
deletes would either fail (FK constraints) or cascade-destroy history.

### Worker dimension table
Created a centralized `workers` table referenced by prep_lists, deliveries,
and worker_shifts via worker_id FK.
Rationale: Original schema used free-text worker names across three tables,
preventing cross-activity analysis and risking data quality issues from name
spelling variations.

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

---

## Data Modeling — Raw vs. Cleaned Staging Pattern

### Two-stage order ingestion
Incoming customer orders land in `incoming_orders_raw` as unparsed text
(SMS, email, phone notes), then get parsed into structured rows in
`orders_cleaned` with a `raw_order_id` FK back to the source.
Rationale: Mirrors real ELT practice — preserve the immutable source record,
transform into a clean analytical layer. If parsing logic changes, the raw
messages are still there to reprocess. `parsed_status` tracks each raw
record's state (pending / cleaned / rejected) so nothing is silently dropped.

---

## Data Generation Approach

### Master data seeding via Python scripts
Chose Python + psycopg2 over manual SQL imports because:
- Reproducible and version-controlled
- Handles errors gracefully (skip vs crash)
- Programmatic control over distributions and randomness
- Matches production data engineering practice

### Idempotent loads via ON CONFLICT (all tables)
All seed and fact-generation scripts use `ON CONFLICT DO UPDATE`:
- Safe to re-run without duplicates
- `xmax = 0` trick distinguishes fresh inserts from conflict updates
- Preserves referential integrity across dimension and fact loads
- Explicit `updated_at = CURRENT_TIMESTAMP` because DEFAULT only fires on
  INSERT, not UPDATE
Rationale: A single consistent idempotency pattern across every load script
is simpler to reason about and maintain than mixing strategies. Re-running
any script is always safe.

### Domain-specific data over generic Faker
Hand-crafted:
- Product catalog (Chinese-American vegetables)
- Restaurant/grocery name generators (weighted prefix + suffix lists)
- Supplier list (Bay Area produce distribution context)
- Worker names and roles

Generic Faker output would have undermined the project's narrative. Faker is
used only where it adds value: signup dates, individual customer names.

### FK resolution via lookup maps
Products reference suppliers by name in source data (readability), resolved
to IDs via one-time query at script start:
1. Query dimension table: `SELECT id, name FROM suppliers`
2. Build lookup dict: `{name: id for id, name in rows}`
3. For each record: translate name → id before insert
4. Skip records with missing references (log warning, continue)

This pattern extends to fact tables that reference multiple dimensions
(customers, products, workers).

### Configuration via environment variables
Database credentials stored in `.env` file (gitignored), loaded via
`python-dotenv`. Follows 12-factor app methodology — configuration outside
code, no secrets in source control.

### Reproducibility via random seeds
`Faker.seed(42)` and `random.seed(42)` make "random" data deterministic.
Anyone cloning the repo gets identical data. Enables reliable testing of
idempotency (same input → same output).

---

## Fact Table Generation Decisions

### Nullable confirmed_quantity
`order_items.confirmed_quantity` is intentionally nullable — an unconfirmed
line item is NULL, not 0.
Rationale: NULL means "not yet decided"; 0 means "confirmed zero available."
Conflating them would distort fill-rate math. Queries use
COALESCE(confirmed_quantity, 0) explicitly where a 0 assumption is intended,
making the treatment visible rather than hidden.

### Uniform random generation (scope note)
Fact data uses uniform random generation (random.randint, random.choice)
rather than weighted business distributions.
Rationale: For an MVP focused on demonstrating modeling, pipeline, and query
skills, uniform data was sufficient to exercise the full stack. A production
or v2 version would introduce weighted distributions (e.g., order frequency
by customer type, seasonal demand) to make the analytics reflect realistic
business behavior — a clear, scoped next step rather than a hidden gap.

---

## Analytics Query Decisions

### CTEs for readable multi-stage logic
Aggregation-then-window queries (weekly fill rate, rolling delivery rate)
are structured as CTEs: aggregate to the grain first, then apply window
functions in the outer query.
Rationale: Window functions can't operate on aggregates computed in the same
SELECT. The CTE creates the row set the window then slides over. Also far
more readable and debuggable than nested subqueries.

### Weighted rolling rates over averaged rates
Rolling on-time delivery % sums the numerator and denominator separately over
the trailing window, then divides once — rather than averaging daily
percentages.
Rationale: Days with different delivery volumes shouldn't carry equal weight.
A 3-delivery day and a 50-delivery day are not equivalent data points.
Summing then dividing produces a volume-weighted rate that reflects reality.

### NULLIF guards on every division
All rate calculations wrap the denominator in NULLIF(x, 0).
Rationale: Prevents divide-by-zero errors on empty periods (a week with no
orders, a day with no scheduled deliveries) — the query returns NULL for that
period instead of crashing.

---

## Known Data Quality Notes (Honest Disclosure)

### total_value / line-item mismatch
The denormalized `total_value` on orders_cleaned does not reconcile with
SUM(order_items.unit_price * confirmed_quantity). The two values were
generated independently rather than derived from one another, so the stored
total and the computed line-item total diverge (verified via a reconciliation
query across orders — the differences are large and vary in direction,
confirming independent generation rather than rounding drift).
Decision: Documented rather than silently patched. In production this would
be caught by a reconciliation test in the transform layer, and the stored
total would be derived from line items or removed in favor of computing it.
Flagging it here demonstrates the exact data-quality check a real pipeline
needs.

### Synthetic data disclaimer
All data is synthetically generated. It models a Bay Area Chinese-American
produce distributor for demonstration purposes but does not represent a real
company. Because generation uses uniform randomness, the analytical trends
are illustrative of the queries' capabilities rather than realistic business
patterns.

---

## Documentation & Artifacts

### ERD generated from live schema
The ERD was authored in DBML and rendered via dbdiagram.io, exported as PNG
and shared via a public link. The diagram reflects the live schema rather
than a hand-drawn mockup.