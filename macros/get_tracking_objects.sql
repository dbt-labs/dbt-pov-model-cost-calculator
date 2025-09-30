{% macro get_tracking_database() %}
  {% set tracking_database = target.database %}
  {{ return(tracking_database) }}
{% endmacro %}

{% macro get_tracking_schema() %}
  {% set tracking_schema = var('artifact_schema', target.schema) %}
  {{ return(tracking_schema) }}
{% endmacro %}

{% macro get_tracking_table() %}
  {% set tracking_table = var('artifact_table', 'dbt_model_executions') %}
  {{ return(tracking_table) }}
{% endmacro %}

{% macro get_job_runs_tracking_table() %}
  {% set tracking_table = var('artifact_job_runs_table', 'dbt_platform_job_runs') %}
  {{ return(tracking_table) }}
{% endmacro %}

{% macro get_tracking_schema_fqn() %}
  {% set tracking_database = dbt_pov_model_cost_calculator.get_tracking_database() %}
  {% set tracking_schema = dbt_pov_model_cost_calculator.get_tracking_schema() %}

  {{ return(adapter.quote_as_configured(tracking_database, 'database') ~ '.' ~ adapter.quote_as_configured(tracking_schema, 'schema')) }}
{% endmacro %}

{% macro get_tracking_table_fqn() %}
  {% set tracking_database = dbt_pov_model_cost_calculator.get_tracking_database() %}
  {% set tracking_schema = dbt_pov_model_cost_calculator.get_tracking_schema() %}
  {% set tracking_table = dbt_pov_model_cost_calculator.get_tracking_table() %}

  {{ return(adapter.quote_as_configured(tracking_database, 'database') ~ '.' ~ adapter.quote_as_configured(tracking_schema, 'schema') ~ '.' ~ adapter.quote_as_configured(tracking_table, 'identifier')) }}
{% endmacro %}

{% macro get_job_runs_tracking_table_fqn() %}
  {% set tracking_database = dbt_pov_model_cost_calculator.get_tracking_database() %}
  {% set tracking_schema = dbt_pov_model_cost_calculator.get_tracking_schema() %}
  {% set tracking_job_runs_table = dbt_pov_model_cost_calculator.get_job_runs_tracking_table() %}

  {{ return(adapter.quote_as_configured(tracking_database, 'database') ~ '.' ~ adapter.quote_as_configured(tracking_schema, 'schema') ~ '.' ~ adapter.quote_as_configured(tracking_job_runs_table, 'identifier')) }}
{% endmacro %}
