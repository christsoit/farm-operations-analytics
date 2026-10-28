-- A line can never confirm more units than the customer requested.
-- Mirrors the Postgres CHECK constraint chk_order_item_quantities.
select order_item_id, requested_quantity, confirmed_quantity
from {{ ref('fct_order_items') }}
where confirmed_quantity > requested_quantity
   or confirmed_quantity < 0
