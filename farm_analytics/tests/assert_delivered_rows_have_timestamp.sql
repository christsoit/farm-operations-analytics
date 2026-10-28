-- A delivery marked 'delivered' must have an actual delivery time,
-- otherwise it silently drops out of the on-time rate.
select delivery_id, delivery_status, delivered_at
from {{ ref('fct_deliveries') }}
where delivery_status = 'delivered'
  and delivered_at is null
