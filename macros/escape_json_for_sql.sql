{% macro escape_json_for_sql(json_string) %}
  {# 
    Properly escape a JSON string for embedding in SQL.
    Must escape backslashes first, then single quotes.
    This ensures the JSON remains valid when parsed by the database.
  #}
  {% set escaped = json_string | replace('\\', '\\\\') | replace("'", "''") %}
  {{ return(escaped) }}
{% endmacro %}

