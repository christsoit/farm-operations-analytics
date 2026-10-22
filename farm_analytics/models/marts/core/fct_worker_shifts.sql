-- Grain: one row per worker x shift date x task x order.
-- Labor cost is computed here rather than stored (cheap single-row math,
-- see docs/decisions.md "Denormalization strategy").

with shifts as (
    select * from {{ ref('stg_worker_shifts') }}
),

workers as (
    select * from {{ ref('stg_workers') }}
)

select
    shifts.shift_id,
    shifts.worker_id,
    workers.worker_name,
    workers.worker_role,
    shifts.shift_date,
    shifts.task_type,
    shifts.hours_worked,
    shifts.hourly_rate,
    shifts.hours_worked * shifts.hourly_rate  as labor_cost,
    shifts.related_order_id
from shifts
inner join workers on shifts.worker_id = workers.worker_id
