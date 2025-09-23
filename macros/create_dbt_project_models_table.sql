{% macro create_dbt_project_models_table() %}
  {% if execute %}
    {% set tracking_table = var('artifact_table', 'dbt_model_executions') %}
    {% set tracking_schema = var('artifact_schema', target.schema) %}
    {% set tracking_database = target.database %}
    {% set datatypes = dbt_model_build_reporter.get_adapter_datatypes() %}
    
    {% set create_schema_sql %}
      create schema if not exists {{ adapter.quote(tracking_database) }}.{{ adapter.quote(tracking_schema) }};
    {% endset %}
    {% set create_table_sql %}
      

      create table if not exists {{ adapter.quote(tracking_database) }}.{{ adapter.quote(tracking_schema) }}.{{ adapter.quote(tracking_table) }} (
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
        node_config {{ datatypes.varchar }}
      )
    {% endset %}
    
    {{ log("Creating artifact tracking table: " ~ tracking_database ~ "." ~ tracking_schema ~ "." ~ tracking_table, info=true) }}
    {% do run_query(create_schema_sql) %}
    {% do run_query(create_table_sql) %}
    {{ log("Successfully created artifact tracking table", info=true) }}
  {% endif %}
{% endmacro %}
