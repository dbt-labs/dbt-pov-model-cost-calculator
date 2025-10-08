{% macro get_adapter_datatypes() %}
  {% set datatypes = {
    'varchar': dbt.type_string(),
    'text': dbt_pov_model_cost_calculator.type_text(),
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
  {% elif target.type == 'redshift' %}
    {{ return('super') }}
  {% else %}
    {{ return('variant') }}
  {% endif %}
{% endmacro %}

{% macro type_text() %}
  {% if target.type == 'redshift' %}
    {{ return('varchar(65535)') }}
  {% elif target.type == 'bigquery' %}
    {{ return('string') }}
  {% elif target.type == 'databricks' %}
    {{ return('string') }}
  {% else %}
    {{ return('text') }}
  {% endif %}
{% endmacro %}

{% macro type_json_insert(data) %}
  {% if target.type == 'bigquery' %}
    {{ return('json ' ~ "'" ~ data ~ "'") }}
  {% elif target.type == 'redshift' %}
    {{ return( 'json_parse(' ~ "'" ~ data ~ "'" ~ ')' )  }}
  {% else  %}
    {{ return( 'parse_json(' ~ "'" ~ data ~ "'" ~ ')' )  }}
  {% endif %}
{% endmacro %}
