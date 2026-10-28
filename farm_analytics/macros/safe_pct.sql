{#
  Percentage with a divide-by-zero guard, rounded.
  Usage: {{ safe_pct('sum(confirmed)', 'sum(requested)') }}
#}
{% macro safe_pct(numerator, denominator, scale=2) -%}
    round(({{ numerator }}) * 100.0 / nullif({{ denominator }}, 0), {{ scale }})
{%- endmacro %}
