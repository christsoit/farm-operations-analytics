with source as (
    select * from {{ source('raw', 'deliveries') }}
)

select
    delivery_id,
    order_id,
    cast(scheduled_delivery_time as timestamp) as scheduled_at,
    -- NULL until the delivery is completed
    cast(actual_delivery_time as timestamp)    as delivered_at,
    lower(trim(delivery_status))        as delivery_status,
    driver_worker_id,
    delivery_address
from source
