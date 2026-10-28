-- One row per order line, joined to its order, customer and product.
-- Central place for line-level business logic so every KPI agrees:
--   confirmed revenue = confirmed qty x unit price (unconfirmed counts as 0)
--   shortage          = requested qty not confirmed

with items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

products as (
    select * from {{ ref('stg_products') }}
)

select
    items.order_item_id,
    items.order_id,
    orders.order_date,
    cast(date_trunc('week', orders.order_date) as date)       as order_week,
    orders.order_status,
    orders.customer_id,
    customers.customer_name,
    customers.market_type,
    items.product_id,
    products.product_name,
    products.category,
    products.source_type,
    items.item_status,
    items.requested_quantity,
    coalesce(items.confirmed_quantity, 0)                     as confirmed_quantity,
    items.requested_quantity - coalesce(items.confirmed_quantity, 0) as shortage_quantity,
    items.unit_price,
    coalesce(items.confirmed_quantity, 0) * items.unit_price  as confirmed_revenue,
    items.requested_quantity * items.unit_price               as requested_value
from items
inner join orders    on items.order_id = orders.order_id
inner join customers on orders.customer_id = customers.customer_id
inner join products  on items.product_id = products.product_id
