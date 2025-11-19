{% macro is_adapter_type(adapter_type) %}
  {# Check if the current adapter matches the specified type #}
  {{ return(target.type == adapter_type) }}
{% endmacro %}

{% macro is_target_enabled() %}
  {# Check if current target is enabled based on enabled_targets variable #}
  {% set enabled_targets = var('enabled_targets', none) %}
  
  {# If no target filter is specified, tracking is enabled for all targets #}
  {% if enabled_targets is none %}
    {{ return(true) }}
  {% endif %}
  
  {# Check if current target is in the allowed list #}
  {% set target_is_enabled = (target.name in enabled_targets) %}
  {{ return(target_is_enabled) }}
{% endmacro %}

{% macro is_enabled(adapter_type) %}
  
  {% set adapter_matches = (target.type == adapter_type) %}
  
  {% if not adapter_matches %}
    {{ return(false) }}
  {% endif %}
  
  {{ return(is_target_enabled()) }}
{% endmacro %}
