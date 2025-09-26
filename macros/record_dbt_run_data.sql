{% macro record_dbt_run_data() %}
  {% if execute %}
    {% set tracking_job_runs_table_fqn = dbt_model_build_reporter.get_job_runs_tracking_table_fqn() %}
    
    {# Collect essential dbt Cloud environment variables #}
    {% set dbt_cloud_run_id = env_var('DBT_CLOUD_RUN_ID', 'none') %}
    {% set dbt_cloud_job_id = env_var('DBT_CLOUD_JOB_ID', 'none') %}
    {% set dbt_cloud_project_id = env_var('DBT_CLOUD_PROJECT_ID', 'none') %}
    {% set dbt_cloud_environment_id = env_var('DBT_CLOUD_ENVIRONMENT_ID', 'none') %}
    {% set dbt_cloud_account_id = env_var('DBT_CLOUD_ACCOUNT_ID', 'none') %}
    {% set dbt_cloud_environment_name = env_var('DBT_CLOUD_ENVIRONMENT_NAME', 'none') %}
    {% set dbt_cloud_environment_type = env_var('DBT_CLOUD_ENVIRONMENT_TYPE', 'none') %}
    {% set dbt_cloud_invocation_context = env_var('DBT_CLOUD_INVOCATION_CONTEXT', 'none') %}
    {% set dbt_cloud_run_reason_category = env_var('DBT_CLOUD_RUN_REASON_CATEGORY', 'none') %}
    {% set dbt_cloud_run_reason = env_var('DBT_CLOUD_RUN_REASON', 'none') %}
    {% set dbt_cloud_git_branch = env_var('DBT_CLOUD_GIT_BRANCH', 'none') %}
    {% set dbt_cloud_git_sha = env_var('DBT_CLOUD_GIT_SHA', 'none') %}
    {% set dbt_version = dbt_version %}
    {% set query_tag = target.query_tag if target.query_tag is defined else 'null' %}
    {% set invocation_id = invocation_id %}
    
    {# Create JSON object with essential dbt platform environment variables #}
    {% set dbt_run_context = {
      'dbt_cloud_run_id': dbt_cloud_run_id,
      'dbt_cloud_job_id': dbt_cloud_job_id,
      'dbt_cloud_project_id': dbt_cloud_project_id,
      'dbt_cloud_environment_id': dbt_cloud_environment_id,
      'dbt_cloud_account_id': dbt_cloud_account_id,
      'dbt_cloud_environment_name': dbt_cloud_environment_name,
      'dbt_cloud_environment_type': dbt_cloud_environment_type,
      'dbt_cloud_invocation_context': dbt_cloud_invocation_context,
      'dbt_cloud_run_reason_category': dbt_cloud_run_reason_category,
      'dbt_cloud_run_reason': dbt_cloud_run_reason,
      'dbt_cloud_git_branch': dbt_cloud_git_branch,
      'dbt_cloud_git_sha': dbt_cloud_git_sha,
      'invocation_id': invocation_id,
      'dbt_version': dbt_version,
      'target_query_tag': query_tag
    } %}
    
    {% set insert_sql %}
      insert into {{ tracking_job_runs_table_fqn }} (
        dbt_cloud_run_id,
        dbt_cloud_job_id,
        dbt_cloud_environment_id,
        dbt_cloud_project_id,
        dbt_run_context
      ) select 
        {% if dbt_cloud_run_id != 'none' %}'{{ dbt_cloud_run_id }}'{% else %}null{% endif %},
        {% if dbt_cloud_job_id != 'none' %}'{{ dbt_cloud_job_id }}'{% else %}null{% endif %},
        {% if dbt_cloud_environment_id != 'none' %}'{{ dbt_cloud_environment_id }}'{% else %}null{% endif %},
        {% if dbt_cloud_project_id != 'none' %}'{{ dbt_cloud_project_id }}'{% else %}null{% endif %},
        {{ dbt_model_build_reporter.type_json_insert(tojson(dbt_run_context)) }}
      
    {% endset %}
    
    {{ log("Recording dbt run data for run_id: " ~ dbt_cloud_run_id, info=true) }}
    {% do run_query(insert_sql) %}
    {{ log("Successfully recorded dbt run data", info=true) }}
  {% endif %}
{% endmacro %}
