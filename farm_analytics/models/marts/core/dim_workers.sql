select
    worker_id,
    worker_name,
    worker_role,
    hire_date,
    is_active
from {{ ref('stg_workers') }}
