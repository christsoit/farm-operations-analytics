-- Customer revenue ranking and Pareto quartiles (KPI queries 8 and 9).
with customer_revenue as (
    select
        customer_id,
        customer_name,
        market_type,
        count(distinct order_id)    as order_count,
        sum(confirmed_revenue)      as revenue
    from {{ ref('fct_order_items') }}
    group by customer_id, customer_name, market_type
),

ranked as (
    select
        *,
        rank() over (order by revenue desc)                           as overall_rank,
        rank() over (partition by market_type order by revenue desc)  as rank_within_market,
        ntile(4) over (order by revenue desc)                         as revenue_quartile,
        sum(revenue) over (order by revenue desc rows between unbounded preceding and current row)
            / nullif(sum(revenue) over (), 0) * 100                   as cumulative_revenue_pct
    from customer_revenue
)

select
    customer_id,
    customer_name,
    market_type,
    order_count,
    round(revenue, 2)                   as revenue,
    overall_rank,
    rank_within_market,
    revenue_quartile,
    case revenue_quartile
        when 1 then 'Top 25%'
        when 2 then 'Upper mid'
        when 3 then 'Lower mid'
        else 'Bottom 25%'
    end                                 as revenue_segment,
    round(cumulative_revenue_pct, 1)    as cumulative_revenue_pct
from ranked
