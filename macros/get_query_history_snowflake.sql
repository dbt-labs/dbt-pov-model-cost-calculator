{% macro get_query_history_snowflake() %}
  {% set tracking_table = var('artifact_table', 'dbt_model_executions') %}
  {% set tracking_schema = var('artifact_schema', target.schema) %}
  {% set tracking_database = target.database %}
  
  select 
    queries.query_id,
    dbt.model_name,
    dbt.model_package,
    dbt.dbt_cloud_job_id,
    dbt.dbt_cloud_run_id,
    dbt.execution_time,
    dbt.status,
    dbt.invocation_id,
    queries.query_text,
    queries.bytes_scanned,
    queries.bytes_spilled_to_local_storage,
    queries.bytes_spilled_to_remote_storage,
    queries.bytes_sent_over_the_network,
    queries.credits_used_cloud_services,
    queries.total_elapsed_time,
    queries.execution_time as snowflake_execution_time,
    queries.queued_overload_time,
    queries.warehouse_name,
    queries.warehouse_size,
    queries.bytes_scanned / (1024*1024*1024) as gb_scanned,


  from {{ tracking_database }}.{{ tracking_schema }}.{{ tracking_table }} as dbt
  left join snowflake.account_usage.query_history as queries
    on queries.query_text like '%' || dbt.model_name || '%'
    and queries.query_text like '%"dbt_cloud_job_id": "' || dbt.dbt_cloud_job_id || '",%'
    and queries.query_text not like '%{{ tracking_table }}%'
    and queries.query_type = 'SELECT'

  where dbt.dbt_cloud_job_id is not null
    and dbt.dbt_cloud_job_id != 'none'
    and dbt.model_name != 'model_queries'
    and queries.start_time >= dbt.run_started_at
    and queries.start_time <= timestampadd(second, dbt.execution_time, dbt.run_started_at)
{% endmacro %}
