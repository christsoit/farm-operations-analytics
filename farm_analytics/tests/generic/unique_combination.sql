{#
  Grain test: no two rows share the same combination of `columns`.
  Example: one inventory row per product, date and warehouse.
#}
{% test unique_combination(model, columns) %}

select
    {{ columns | join(', ') }},
    count(*) as row_count
from {{ model }}
group by {{ columns | join(', ') }}
having count(*) > 1

{% endtest %}
