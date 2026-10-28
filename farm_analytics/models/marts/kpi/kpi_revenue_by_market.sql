-- Revenue mix by market segment (KPI query 10).
with by_market as (
    select
        market_type,
        count(distinct customer_id) as customer_count,
        count(distinct order_id)    as order_count,
        sum(confirmed_revenue)      as revenue
    from {{ ref('fct_order_items') }}
    group by market_type
)

select
    market_type,
    customer_count,
    order_count,
    round(revenue, 2)                                         as revenue,
    {{ safe_pct('revenue', 'sum(revenue) over ()', 1) }}      as pct_of_total_revenue
from by_market
