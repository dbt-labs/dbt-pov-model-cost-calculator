{% macro get_dbt_cloud_run_id() %}
  {{ return(env_var('DBT_CLOUD_RUN_ID',
  run_started_at.strftime('%Y%m%d_%H%M%S_%f')[:-3])) }}
{% endmacro %}

{% macro get_dbt_cloud_job_id() %}
  {{ return(env_var('DBT_CLOUD_JOB_ID', invocation_id)) }}
{% endmacro %}
