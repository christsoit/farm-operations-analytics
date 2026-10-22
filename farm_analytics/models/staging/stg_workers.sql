with source as (
    select * from {{ source('raw', 'workers') }}
)

select
    worker_id,
    trim(worker_name)                   as worker_name,
    lower(trim(role))                   as worker_role,
    cast(hire_date as date)             as hire_date,
    is_active
from source
