-- Daily on-time delivery with a volume-weighted 7-day rolling rate (KPI query 6).
with daily as (
    select
        scheduled_date              as delivery_date,
        count(*)                    as deliveries,
        sum(is_on_time)             as on_time_deliveries
    from {{ ref('fct_deliveries') }}
    group by scheduled_date
)

select
    delivery_date,
    deliveries,
    on_time_deliveries,
    {{ safe_pct('on_time_deliveries', 'deliveries', 1) }} as on_time_pct,
    {{ safe_pct(
        'sum(on_time_deliveries) over (order by delivery_date rows between 6 preceding and current row)',
        'sum(deliveries) over (order by delivery_date rows between 6 preceding and current row)',
        1
    ) }} as rolling_7day_on_time_pct
from daily
