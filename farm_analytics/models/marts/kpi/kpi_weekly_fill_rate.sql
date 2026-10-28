-- Weekly fill rate with a 4-week rolling average (KPI query 5).
with weekly as (
    select
        order_week                  as week_start,
        sum(requested_quantity)     as requested_quantity,
        sum(confirmed_quantity)     as confirmed_quantity
    from {{ ref('fct_order_items') }}
    group by order_week
)

select
    week_start,
    requested_quantity,
    confirmed_quantity,
    {{ safe_pct('confirmed_quantity', 'requested_quantity') }} as weekly_fill_rate_pct,
    -- Same as the original Postgres query: simple average of the last 4 weekly rates
    round(avg(confirmed_quantity * 100.0 / nullif(requested_quantity, 0))
        over (order by week_start rows between 3 preceding and current row), 2) as rolling_4wk_avg_pct,
    -- Volume-weighted version: a quiet week can't swing the average as much as a busy one
    {{ safe_pct(
        'sum(confirmed_quantity) over (order by week_start rows between 3 preceding and current row)',
        'sum(requested_quantity) over (order by week_start rows between 3 preceding and current row)'
    ) }} as rolling_4wk_fill_rate_pct
from weekly
