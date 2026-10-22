-- Grain: one row per cleaned order.
-- Compares the denormalized header totals stored at intake (total_items,
-- total_value) with totals rebuilt from the line items. Differences point to
-- intake or parsing errors -- the same "header doesn't match line items"
-- reconciliation check used in daily operations.

with orders as (
    select * from {{ ref('stg_orders') }}
),

line_totals as (
    select
        order_id,
        count(*)                as line_count,
        sum(requested_value)    as line_requested_value,
        sum(confirmed_revenue)  as line_confirmed_revenue,
        sum(requested_quantity) as line_requested_quantity,
        sum(confirmed_quantity) as line_confirmed_quantity
    from {{ ref('int_order_items_enriched') }}
    group by order_id
)

select
    orders.order_id,
    orders.raw_order_id,
    orders.customer_id,
    orders.order_date,
    orders.requested_delivery_date,
    orders.order_status,
    orders.cleaning_status,
    orders.total_items                                   as header_total_items,
    orders.total_value                                   as header_total_value,
    coalesce(line_totals.line_count, 0)                  as line_count,
    coalesce(line_totals.line_requested_value, 0)        as line_requested_value,
    coalesce(line_totals.line_confirmed_revenue, 0)      as confirmed_revenue,
    {{ safe_pct('line_totals.line_confirmed_quantity', 'line_totals.line_requested_quantity') }} as fill_rate_pct,
    orders.total_value - coalesce(line_totals.line_requested_value, 0) as header_value_variance,
    case
        when orders.total_items is null then 'no_header_total'
        when orders.total_items <> coalesce(line_totals.line_count, 0) then 'item_count_mismatch'
        when abs(orders.total_value - coalesce(line_totals.line_requested_value, 0)) > 0.01 then 'value_mismatch'
        else 'reconciled'
    end                                                  as reconciliation_status
from orders
left join line_totals on orders.order_id = line_totals.order_id
