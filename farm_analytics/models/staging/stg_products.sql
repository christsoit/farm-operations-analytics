with source as (
    select * from {{ source('raw', 'products') }}
)

select
    product_id,
    trim(product_name)                  as product_name,
    category,
    unit,
    cast(standard_price as decimal(10, 2)) as standard_price,
    lower(trim(source_type))            as source_type,
    supplier_id,
    is_active
from source
