-- Reconciliation check: header totals stored at intake vs. totals rebuilt
-- from line items. Severity = warn, because mismatches are an expected
-- data-quality signal to review, not a reason to stop the pipeline.
{{ config(severity='warn') }}

select order_id, reconciliation_status, header_total_items, line_count, header_value_variance
from {{ ref('fct_orders') }}
where reconciliation_status in ('item_count_mismatch', 'value_mismatch')
