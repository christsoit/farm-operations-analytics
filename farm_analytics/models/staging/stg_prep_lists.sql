with source as (
    select * from {{ source('raw', 'prep_lists') }}
)

select
    prep_id,
    order_id,
    product_id,
    cast(quantity_to_prepare as decimal(10, 2)) as quantity_to_prepare,
    lower(trim(prep_status))            as prep_status,
    assigned_worker_id,
    cast(prep_date as date)             as prep_date
from source
