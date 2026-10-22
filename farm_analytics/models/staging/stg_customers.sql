with source as (
    select * from {{ source('raw', 'customers') }}
)

select
    customer_id,
    trim(customer_name)                 as customer_name,
    lower(trim(market_type))            as market_type,
    region,
    cast(signup_date as date)           as signup_date,
    is_active,
    cast(created_at as timestamp)       as created_at,
    cast(updated_at as timestamp)       as updated_at
from source
