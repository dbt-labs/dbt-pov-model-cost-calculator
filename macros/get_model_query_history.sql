{% macro get_model_query_history() %}
  {# Main macro that dispatches to adapter-specific query history macros #}
  
  {% if target.type == 'bigquery' %}
    {{ return(get_query_history_bigquery()) }}
  {% elif target.type == 'databricks' %}
    {{ return(get_query_history_databricks()) }}
  {% elif target.type == 'snowflake' %}
    {{ return(get_query_history_snowflake()) }}
  {% else %}
    {# Raise compiler error for unsupported adapters #}
    {{ exceptions.raise_compiler_error(
      "The model_queries model is not supported for adapter type '" ~ target.type ~ "'. " ~
      "Supported adapters are: bigquery, databricks, snowflake. " ~
      "To use this model, please switch to one of the supported adapters or " ~
      "modify the get_model_query_history macro to add support for your adapter."
    ) }}
  {% endif %}
{% endmacro %}
