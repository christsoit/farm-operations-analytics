# farm_analytics (dbt on Snowflake)

The transformation layer for Farm Operations Analytics. Operational tables are
copied from PostgreSQL into `FARM_OPS.RAW` in Snowflake, and dbt builds a
tested dimensional model and dashboard-ready KPI tables on top.

```
PostgreSQL ──load_to_snowflake.py──▶ RAW ──dbt──▶ STAGING ─▶ (intermediate) ─▶ CORE ─▶ KPI ──▶ Tableau
             (full refresh, EL)       11 tables   11 views    ephemeral         7 tables 10 tables
```

## Layers

| Layer | Materialization | What it does |
|---|---|---|
| `staging/` | view | 1:1 with each RAW table: rename, cast types, normalize enum casing |
| `intermediate/` | ephemeral | Shared business logic defined once: line revenue/shortage, on-time flag |
| `marts/core/` | table | `dim_customers`, `dim_products`, `dim_workers`, `fct_order_items`, `fct_orders`, `fct_deliveries`, `fct_worker_shifts` |
| `marts/kpi/` | table | One table per dashboard view, ported from the 13 Postgres KPI queries |

## Tests (`dbt build` runs them all)

- **Keys and grain:** `unique` / `not_null` on every primary key; a custom
  `unique_combination` generic test for multi-column grains (inventory, order lines).
- **Referential integrity:** `relationships` tests replace the Postgres foreign keys,
  which Snowflake does not enforce.
- **Enums:** `accepted_values` on every status column, mirroring the Postgres CHECK constraints.
- **Business rules (singular tests):**
  - confirmed quantity never exceeds requested
  - every `delivered` row has a delivery timestamp
  - revenue ties out between `kpi_revenue_by_market` and `kpi_overview`
  - **reconciliation (warn):** order header totals vs. totals rebuilt from line
    items, surfaced in `fct_orders.reconciliation_status`

## Run it

```bash
pip install -r ../requirements-snowflake.txt
cp profiles.yml.example profiles.yml      # reads credentials from env vars
python ../scripts/load_to_snowflake.py    # Postgres -> RAW
dbt build                                 # dev: DBT_DEV_* schemas
dbt build --target prod                   # prod: STAGING / CORE / KPI
dbt docs generate && dbt docs serve       # lineage graph + column docs
```

Scheduled runs: `.github/workflows/dbt_build.yml` runs `dbt build --target prod`
daily and on every push to `main` that changes this folder.
