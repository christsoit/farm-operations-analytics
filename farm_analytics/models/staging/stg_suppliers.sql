with source as (
    select * from {{ source('raw', 'suppliers') }}
)

select
    supplier_id,
    trim(supplier_name)                 as supplier_name,
    supplier_region,
    lower(trim(supplier_type))          as supplier_type,
    is_local,
    is_active
from source
