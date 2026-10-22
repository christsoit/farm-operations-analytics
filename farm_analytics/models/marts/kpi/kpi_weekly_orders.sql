-- Weekly order volume and confirmed revenue (KPI query 3).
-- Revenue is rebuilt from line items, not the denormalized header total.
select
    cast(date_trunc('week', order_date) as date) as week_start,
    count(*)                                     as orders,
    round(sum(confirmed_revenue), 2)             as weekly_revenue
from {{ ref('fct_orders') }}
group by 1
