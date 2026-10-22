with source as (
    select * from {{ source('raw', 'orders_cleaned') }}
)

select
    order_id,
    raw_order_id,
    customer_id,
    cast(order_date as date)            as order_date,
    cast(requested_delivery_date as date) as requested_delivery_date,
    lower(trim(order_status))           as order_status,
    lower(trim(cleaning_status))        as cleaning_status,
    total_items,
    cast(total_value as decimal(10, 2)) as total_value,
    notes
from source
