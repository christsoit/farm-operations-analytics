with source as (
    select * from {{ source('raw', 'worker_shifts') }}
)

select
    shift_id,
    worker_id,
    cast(shift_date as date)            as shift_date,
    lower(trim(task_type))              as task_type,
    cast(hours_worked as decimal(5, 2)) as hours_worked,
    cast(hourly_rate as decimal(10, 2)) as hourly_rate,
    related_order_id,
    notes
from source
