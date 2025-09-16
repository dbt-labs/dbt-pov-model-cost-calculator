{{ config(
    enabled=dbt_model_build_logger.is_adapter_type('snowflake'),
    materialized='view'
) }}

{% set tracking_table = var('artifact_table', 'dbt_model_executions') %}
{% set tracking_schema = var('artifact_schema', target.schema) %}
{% set tracking_database = target.database %}
{% set monitor_start_date = var('model_monitor_start_date', (modules.datetime.datetime.now() - modules.datetime.timedelta(days=30)).strftime('%Y-%m-%d')) %}

select 
  queries.query_id,
  dbt.model_name,
  dbt.relation_name,
  dbt.model_package,
  dbt.dbt_cloud_job_id,
  dbt.dbt_cloud_run_id,
  dbt.execution_time,
  dbt.status,
  dbt.invocation_id,
  queries.query_text,
  queries.credits_used_cloud_services,
  queries.total_elapsed_time,
  queries.execution_time as snowflake_execution_time,
  queries.queued_overload_time,
  queries.warehouse_name,
  queries.warehouse_size,
  queries.bytes_scanned / (1024*1024*1024) as gb_scanned,
  query_attr.credits_attributed_compute,
  query_attr.credits_used_query_acceleration

from {{ tracking_database }}.{{ tracking_schema }}.{{ tracking_table }} as dbt
left join snowflake.account_usage.query_history as queries
  on queries.query_text like '%' || dbt.model_name || '%'
  and queries.query_text like '%"dbt_cloud_job_id": "' || dbt.dbt_cloud_job_id || '",%'
  and queries.query_text not like '%{{ tracking_table }}%'
  and queries.query_type = 'SELECT'
  and queries.database_name = '{{ tracking_database }}'
  and queries.schema_name = '{{ tracking_schema }}'

left join snowflake.account_usage.query_attribution_history as query_attr
  on query_attr.query_id = queries.query_id

where dbt.dbt_cloud_job_id is not null
  and dbt.dbt_cloud_job_id != 'none'
  and dbt.model_name != 'model_queries'
  and dbt.status = 'success'
  and queries.start_time >= '{{ monitor_start_date }}'
  and queries.start_time >= dbt.run_started_at
  and queries.start_time <= timestampadd(second, dbt.execution_time, dbt.run_started_at)
  and query_attr.start_time >= dbt.run_started_at
  and query_attr.start_time <= timestampadd(second, dbt.execution_time, dbt.run_started_at)
