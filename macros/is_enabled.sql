{% macro is_adapter_type(adapter_type) %}
  {# Check if the current adapter matches the specified type #}
  {{ return(target.type == adapter_type) }}
{% endmacro %}


{% macro is_target_enabled() %}
  {% set is_enabled = var('enable_cost_savings_calculator', true) %}
  {{ return(is_enabled | as_bool) }}
{% endmacro %}


{% macro is_enabled(adapter_type) %}

  {% set adapter_matches = (target.type == adapter_type) %}

  {% if not adapter_matches %}
    {{ return(false) }}
  {% endif %}

  {{ return(is_target_enabled()) }}
{% endmacro %}
