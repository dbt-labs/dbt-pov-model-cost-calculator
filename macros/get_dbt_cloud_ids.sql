{% macro get_dbt_cloud_run_id() %}
  {{ return(env_var('DBT_CLOUD_RUN_ID', 
  modules.datetime.datetime.now().strftime('%Y%m%d_%H%M%S_%f')[:-3])) }}
{% endmacro %}

{% macro get_dbt_cloud_job_id() %}
  {{ return(env_var('DBT_CLOUD_JOB_ID', invocation_id)) }}
{% endmacro %}
