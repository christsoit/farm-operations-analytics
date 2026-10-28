-- One row per delivery with the on-time flag defined once.
-- On time = delivered on the scheduled calendar date (same rule as the
-- original Postgres KPI queries).

with deliveries as (
    select * from {{ ref('stg_deliveries') }}
),

workers as (
    select * from {{ ref('stg_workers') }}
)

select
    deliveries.delivery_id,
    deliveries.order_id,
    cast(deliveries.scheduled_at as date)                     as scheduled_date,
    deliveries.scheduled_at,
    deliveries.delivered_at,
    deliveries.delivery_status,
    deliveries.driver_worker_id,
    workers.worker_name                                       as driver_name,
    workers.worker_role                                       as driver_role,
    case
        when deliveries.delivery_status = 'delivered'
         and cast(deliveries.delivered_at as date) = cast(deliveries.scheduled_at as date)
        then 1 else 0
    end                                                       as is_on_time
from deliveries
left join workers on deliveries.driver_worker_id = workers.worker_id
