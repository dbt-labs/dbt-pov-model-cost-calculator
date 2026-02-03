{% macro is_adapter_type(adapter_type) %}
  {# Check if the current adapter matches the specified type #}
  {{ return(target.type == adapter_type) }}
{% endmacro %}


{% macro is_target_enabled() %}
  {% set is_enabled = var('enable_cost_savings_calculator', True) %}
  {% if is_enabled is string %}
    {% if is_enabled.lower() == 'true' %}
      {% set is_enabled = True %}
    {% elif is_enabled.lower() == 'false' %}
      {% set is_enabled = False %}
    {% endif %}
  {% endif %}
  {{ return(is_enabled) }}
{% endmacro %}


{% macro is_enabled(adapter_type) %}

  {% set adapter_matches = (target.type == adapter_type) %}

  {% if not adapter_matches %}
    {{ return(False) }}
  {% endif %}

  {{ return(is_target_enabled()) }}
{% endmacro %}
