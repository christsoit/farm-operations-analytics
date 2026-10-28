with source as (
    select * from {{ source('raw', 'incoming_orders_raw') }}
)

select
    raw_order_id,
    customer_name_raw,
    order_text,
    cast(received_timestamp as timestamp) as received_at,
    lower(trim(source_channel))         as source_channel,
    entered_by
from source
