{% macro create_dbt_project_models_table() %}
  {% if execute %}
    {% set tracking_table = dbt_pov_model_cost_calculator.get_tracking_table() %}
    {% set tracking_schema = dbt_pov_model_cost_calculator.get_tracking_schema() %}
    {% set tracking_database = dbt_pov_model_cost_calculator.get_tracking_database() %}
    {% set tracking_table_fqn = dbt_pov_model_cost_calculator.get_tracking_table_fqn() %}
    {% set tracking_job_run_table_fqn = dbt_pov_model_cost_calculator.get_job_runs_tracking_table_fqn() %}
    {% set tracking_schema_fqn = dbt_pov_model_cost_calculator.get_tracking_schema_fqn() %}
    {% set datatypes = dbt_pov_model_cost_calculator.get_adapter_datatypes() %}

    {% set create_schema_sql %}
      create schema if not exists {{ tracking_schema_fqn }};
    {% endset %}

    {% set create_table_sql %}
      create table if not exists {{ tracking_table_fqn }} (
        model_name {{ datatypes.varchar }},
        relation_name {{ datatypes.varchar }},
        model_package {{ datatypes.varchar }},
        model_type {{ datatypes.varchar }},
        status {{ datatypes.varchar }},
        execution_time {{ datatypes.float }},
        invocation_id {{ datatypes.varchar }},
        query_id {{ datatypes.varchar }},
        insert_timestamp {{ datatypes.timestamp }},
        dbt_cloud_run_id {{ datatypes.varchar }},
        dbt_cloud_job_id {{ datatypes.varchar }},
        dbt_cloud_project_id {{ datatypes.varchar }},
        dbt_version {{ datatypes.varchar }},
        run_started_at {{ datatypes.timestamp }},
        node_config {{ datatypes.text }}
      )
    {% endset %}

    {% set create_job_run_table_sql %}
      create table if not exists {{ tracking_job_run_table_fqn }} (
        dbt_cloud_run_id {{ datatypes.varchar }},
        dbt_cloud_job_id {{ datatypes.varchar }},
        dbt_cloud_environment_id {{ datatypes.varchar }},
        dbt_cloud_project_id {{ datatypes.varchar }},
        dbt_run_context {{ datatypes.json }}
      )
    {% endset %}

    {{ log("Creating artifact tracking tables: " ~ tracking_table_fqn ~ " and " ~ tracking_job_run_table_fqn, info=true) }}
    {% do run_query(create_schema_sql) %}
    {% do run_query(create_table_sql) %}
    {% do run_query(create_job_run_table_sql) %}
    {{ log("Successfully created artifact tracking tables", info=true) }}
  {% endif %}
{% endmacro %}
