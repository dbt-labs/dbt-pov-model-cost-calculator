{% macro escape_json_for_sql(json_string) %}
  {# 
    Properly escape a JSON string for embedding in SQL.
    Different adapters have different requirements:
    - Snowflake/Databricks: Uses parse_json('...'), needs backslashes doubled and single quotes doubled
    - BigQuery: Uses json '...', needs backslashes doubled and single quotes escaped with backslash
  #}
  {% if target.type == 'bigquery' %}
    {# BigQuery json literal: escape backslashes first, then escape single quotes with backslash #}
    {% set escaped = json_string | replace('\\', '\\\\') | replace("'", "\\'") %}
  {% else %}
    {# Snowflake/Databricks: escape backslashes first, then double single quotes for SQL #}
    {% set escaped = json_string | replace('\\', '\\\\') | replace("'", "''") %}
  {% endif %}
  {{ return(escaped) }}
{% endmacro %}

