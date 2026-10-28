-- Own-farm vs. outsourced fulfillment (KPI query 12).
select
    source_type,
    count(distinct product_id)                                         as product_count,
    sum(requested_quantity)                                            as total_requested,
    sum(confirmed_quantity)                                            as total_confirmed,
    {{ safe_pct('sum(confirmed_quantity)', 'sum(requested_quantity)') }} as fill_rate_pct
from {{ ref('fct_order_items') }}
group by source_type
