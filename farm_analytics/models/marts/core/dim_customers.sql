with customers as (
    select * from {{ ref('stg_customers') }}
),

order_lines as (
    select * from {{ ref('int_order_items_enriched') }}
),

customer_orders as (
    select
        customer_id,
        count(distinct order_id)   as lifetime_orders,
        sum(confirmed_revenue)     as lifetime_revenue,
        min(order_date)            as first_order_date,
        max(order_date)            as last_order_date
    from order_lines
    group by customer_id
)

select
    customers.customer_id,
    customers.customer_name,
    customers.market_type,
    customers.region,
    customers.signup_date,
    customers.is_active,
    coalesce(customer_orders.lifetime_orders, 0)  as lifetime_orders,
    coalesce(customer_orders.lifetime_revenue, 0) as lifetime_revenue,
    customer_orders.first_order_date,
    customer_orders.last_order_date
from customers
left join customer_orders on customers.customer_id = customer_orders.customer_id
