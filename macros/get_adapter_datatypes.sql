{% macro get_adapter_datatypes() %}
  {% if target.type == 'snowflake' %}
    {% set datatypes = {
      'varchar': 'varchar',
      'float': 'float',
      'timestamp': 'timestamp_ntz',
      'integer': 'integer'
    } %}
  {% elif target.type == 'bigquery' %}
    {% set datatypes = {
      'varchar': 'string',
      'float': 'float64',
      'timestamp': 'timestamp',
      'integer': 'int64'
    } %}
  {% elif target.type == 'redshift' %}
    {% set datatypes = {
      'varchar': 'varchar(max)',
      'float': 'float',
      'timestamp': 'timestamp',
      'integer': 'integer'
    } %}
  {% elif target.type == 'postgres' %}
    {% set datatypes = {
      'varchar': 'varchar',
      'float': 'float',
      'timestamp': 'timestamp',
      'integer': 'integer'
    } %}
  {% elif target.type == 'duckdb' %}
    {% set datatypes = {
      'varchar': 'varchar',
      'float': 'double',
      'timestamp': 'timestamp',
      'integer': 'integer'
    } %}
  {% elif target.type == 'sqlite' %}
    {% set datatypes = {
      'varchar': 'text',
      'float': 'real',
      'timestamp': 'text',
      'integer': 'integer'
    } %}
  {% elif target.type == 'spark' %}
    {% set datatypes = {
      'varchar': 'string',
      'float': 'double',
      'timestamp': 'timestamp',
      'integer': 'int'
    } %}
  {% elif target.type == 'databricks' %}
    {% set datatypes = {
      'varchar': 'string',
      'float': 'double',
      'timestamp': 'timestamp',
      'integer': 'int'
    } %}
  {% else %}
    {# Default to generic SQL types if adapter not recognized #}
    {% set datatypes = {
      'varchar': 'varchar',
      'float': 'float',
      'timestamp': 'timestamp',
      'integer': 'integer'
    } %}
  {% endif %}
  
  {{ return(datatypes) }}
{% endmacro %}
