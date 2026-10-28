-- Product demand and shortage ranking (KPI query 11).
with product_stats as (
    select
        product_id,
        product_name,
        category,
        source_type,
        sum(requested_quantity)     as total_requested,
        sum(confirmed_quantity)     as total_confirmed,
        sum(shortage_quantity)      as shortage
    from {{ ref('fct_order_items') }}
    group by product_id, product_name, category, source_type
)

select
    product_id,
    product_name,
    category,
    source_type,
    total_requested,
    total_confirmed,
    shortage,
    {{ safe_pct('shortage', 'total_requested', 1) }}   as shortage_rate_pct,
    rank() over (order by total_requested desc)        as demand_rank,
    rank() over (order by shortage desc)               as shortage_rank
from product_stats
