-- Grain: one row per order line (order x product).
select * from {{ ref('int_order_items_enriched') }}
