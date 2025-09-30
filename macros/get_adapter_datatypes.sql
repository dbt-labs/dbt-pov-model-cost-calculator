{% macro get_adapter_datatypes() %}
  {% set datatypes = {
    'varchar': dbt.type_string(),
    'float': dbt.type_float(),
    'timestamp': dbt.type_timestamp(),
    'integer': dbt.type_int(),
    'json': dbt_pov_model_cost_calculator.type_json(),
  } %}

  {{ return(datatypes) }}
{% endmacro %}

{% macro type_json() %}
  {% if target.type == 'bigquery' %}
    {{ return('json') }}
  {% else %}
    {{ return('variant') }}
  {% endif %}
{% endmacro %}

{% macro type_json_insert(data) %}
  {% if target.type == 'bigquery' %}
    {{ return('json ' ~ "'" ~ data ~ "'") }}
  {% else  %}
    {{ return( 'parse_json(' ~ "'" ~ data ~ "'" ~ ')' )  }}
  {% endif %}
{% endmacro %}
