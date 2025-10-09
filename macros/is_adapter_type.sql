{% macro is_adapter_type(adapter_type) %}
  {# Check if the current adapter matches the specified type #}
  {{ return(target.type == adapter_type) }}
{% endmacro %}