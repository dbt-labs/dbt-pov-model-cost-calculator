{% macro get_query_history_databricks() %}
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
    queries.total_scan_size_bytes,
    queries.execution_time_ms,
    queries.planning_time_ms,
    queries.wait_time_in_queue_ms,
    queries.result_fetch_time_ms,
    queries.query_start_time_ms,
    queries.query_end_time_ms,
    queries.cluster_id,
    queries.warehouse_id,
    queries.total_scan_size_bytes / (1024*1024*1024) as gb_scanned,
    case 
      when queries.total_scan_size_bytes > 0 then 
        (queries.total_scan_size_bytes / (1024*1024*1024)) * 0.5  -- $0.50 per GB for Databricks
      else 0 
    end as estimated_cost_usd

  from {{ tracking_database }}.{{ tracking_schema }}.{{ tracking_table }} as dbt
  left join system.query.history as queries
    on queries.query_text like '%' || dbt.model_name || '%'
    and queries.query_text like '%"dbt_cloud_job_id": "' || dbt.dbt_cloud_job_id || '",%'
    and queries.query_start_time_ms >= unix_timestamp(dbt.run_started_at) * 1000
    and queries.query_start_time_ms <= (unix_timestamp(dbt.run_started_at) + dbt.execution_time) * 1000
    and queries.query_text not like '%{{ tracking_table }}%'

  where dbt.dbt_cloud_job_id is not null
    and dbt.dbt_cloud_job_id != 'none'
    and dbt.model_name != 'model_queries'
{% endmacro %}
