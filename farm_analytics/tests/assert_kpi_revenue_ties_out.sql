-- Revenue must tie out across marts: the market-segment split has to add up
-- to the header total on the dashboard (within 1 cent of rounding).
with a as (select sum(revenue) as v from {{ ref('kpi_revenue_by_market') }}),
     b as (select total_confirmed_revenue as v from {{ ref('kpi_overview') }})
select a.v as by_market, b.v as overview
from a cross join b
where abs(coalesce(a.v, 0) - coalesce(b.v, 0)) > 0.05
