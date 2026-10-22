-- Weekly on-hand inventory by category (KPI query 13).
with inventory as (
    select * from {{ ref('stg_inventory') }}
),

products as (
    select * from {{ ref('dim_products') }}
)

select
    cast(date_trunc('week', inventory.inventory_date) as date) as week_start,
    products.category,
    sum(inventory.available_quantity)                          as total_on_hand,
    round(avg(inventory.available_quantity), 2)                as avg_per_snapshot
from inventory
inner join products on inventory.product_id = products.product_id
group by 1, 2
