-- Dashboard header tiles (single row). Replaces KPI queries 1, 2 and 4.
select
    count(distinct order_id)                                         as total_orders,
    round(sum(confirmed_revenue), 2)                                 as total_confirmed_revenue,
    {{ safe_pct('sum(confirmed_quantity)', 'sum(requested_quantity)') }} as overall_fill_rate_pct
from {{ ref('fct_order_items') }}
