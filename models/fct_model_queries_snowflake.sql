{{ config(
    enabled=dbt_model_build_reporter.is_adapter_type('snowflake'),
    materialized='view',
    alias='fct_dbt_model_queries'
) }}

{% set tracking_table = var('artifact_table', 'dbt_model_executions') %}
{% set tracking_schema = var('artifact_schema', target.schema) %}
{% set tracking_database = target.database %}
{% set monitor_start_date = var('model_monitor_start_date', (modules.datetime.datetime.now() - modules.datetime.timedelta(days=30)).strftime('%Y-%m-%d')) %}
{% set snowflake_query_history_table = var('snowflake_query_history_table', 'snowflake.account_usage.query_history') %}
{% set snowflake_query_attribution_table = var('snowflake_query_attribution_table', 'snowflake.account_usage.query_attribution_history') %}
{% set snowflake_credit_rate = var('snowflake_credit_rate', 3) %}
with queries_with_metadata as (
  select 
      queries.query_id,
      queries.query_text,
      queries.credits_used_cloud_services,
      queries.total_elapsed_time,
      queries.execution_time,
      queries.queued_overload_time,
      queries.warehouse_name,
      queries.warehouse_size,
      queries.bytes_scanned,
      CONVERT_TIMEZONE('UTC', queries.start_time)::TIMESTAMP_NTZ as start_time,
    parse_json(
      regexp_substr(queries.query_text, '/\\* (\{.*?\}) \\*/', 1, 1, 'em')
    ) as query_metadata
  from {{ snowflake_query_history_table }} as queries
  where queries.start_time >= '{{ monitor_start_date }}'
    and queries.database_name = upper('{{ tracking_database }}')
    and queries.query_text not like '%{{ tracking_table }}%'
)

select 
  queries.query_id,
  dbt.run_started_at,
  dbt.model_name,
  dbt.model_package,
  dbt.dbt_cloud_job_id,
  dbt.dbt_cloud_run_id,
  dbt.execution_time,
  dbt.status,
  dbt.invocation_id,
  dbt.dbt_version,

  -- Compute information
  queries.warehouse_name,
  queries.warehouse_size,

  -- Cost information
  queries.credits_used_cloud_services,
  queries.bytes_scanned / (1024*1024*1024) as gb_scanned,
  query_attr.credits_attributed_compute,
  query_attr.credits_attributed_compute * {{ snowflake_credit_rate }} as attributed_compute_cost,

  -- Query metrics
  queries.total_elapsed_time,
  queries.execution_time as snowflake_execution_time

from {{ dbt_model_build_reporter.get_tracking_table_fqn() }} as dbt
inner join queries_with_metadata as queries
  on queries.query_metadata:dbt_cloud_job_id = dbt.dbt_cloud_job_id
  and queries.query_metadata:dbt_cloud_run_id = dbt.dbt_cloud_run_id
  and queries.query_metadata:node_name = dbt.model_name
  and queries.start_time >= dbt.run_started_at
  and queries.start_time <= dbt.insert_timestamp

left join {{ snowflake_query_attribution_table }} as query_attr
  on query_attr.query_id = queries.query_id
 and queries.start_time >= '{{ monitor_start_date }}'

where dbt.dbt_cloud_job_id is not null
  and dbt.dbt_cloud_job_id != 'none'
  and dbt.model_name != 'model_queries'
