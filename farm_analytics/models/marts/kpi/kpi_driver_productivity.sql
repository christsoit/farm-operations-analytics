-- Driver volume vs. quality (KPI query 7): the busiest driver is not always
-- the most reliable, so both ranks are exposed.
with driver_stats as (
    select
        driver_worker_id,
        driver_name,
        driver_role,
        count(*)            as total_deliveries,
        sum(is_on_time)     as on_time_deliveries
    from {{ ref('fct_deliveries') }}
    where driver_worker_id is not null
    group by driver_worker_id, driver_name, driver_role
)

select
    driver_worker_id,
    driver_name,
    driver_role,
    total_deliveries,
    on_time_deliveries,
    {{ safe_pct('on_time_deliveries', 'total_deliveries', 1) }} as on_time_pct,
    rank() over (order by total_deliveries desc) as volume_rank,
    rank() over (order by on_time_deliveries * 1.0 / nullif(total_deliveries, 0) desc) as reliability_rank
from driver_stats
