with source as (
    select * from {{ source('raw', 'order_items') }}
)

select
    order_item_id,
    order_id,
    product_id,
    cast(requested_quantity as decimal(10, 2)) as requested_quantity,
    -- NULL = not yet confirmed (still in cleaning / review)
    cast(confirmed_quantity as decimal(10, 2)) as confirmed_quantity,
    cast(unit_price as decimal(10, 2))  as unit_price,
    lower(trim(item_status))            as item_status
from source
