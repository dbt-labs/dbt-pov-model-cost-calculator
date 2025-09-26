{% macro is_adapter_type(adapter_type) %}
  {# Check if the current adapter matches the specified type #}
  {{ return(target.type == adapter_type) }}
{% endmacro %}

{% macro is_redshift_serverless() %}
  {% set is_serverless = var('is_serverless_redshift', false) %}
  {{ return(is_adapter_type('redshift') and is_serverless) }}
{% endmacro %}

{% macro is_redshift_provisioned() %}
  {% set is_serverless = var('is_serverless_redshift', false) %}
  {{ return(is_adapter_type('redshift') and not is_serverless) }}
{% endmacro %}