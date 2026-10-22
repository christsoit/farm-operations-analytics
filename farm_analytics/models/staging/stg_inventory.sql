with source as (
    select * from {{ source('raw', 'inventory') }}
)

select
    inventory_id,
    product_id,
    cast(inventory_date as date)        as inventory_date,
    cast(available_quantity as decimal(10, 2)) as available_quantity,
    warehouse_location
from source
