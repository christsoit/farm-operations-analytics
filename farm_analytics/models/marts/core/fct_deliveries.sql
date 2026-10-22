-- Grain: one row per delivery (one delivery per order).
select * from {{ ref('int_deliveries_enriched') }}
