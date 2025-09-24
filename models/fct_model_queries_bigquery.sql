{{ config(
    enabled=dbt_model_build_reporter.is_adapter_type('bigquery'),
    materialized='view',
    alias='fct_dbt_model_queries'
) }}

{% set tracking_table = var('artifact_table', 'dbt_model_executions') %}
{% set tracking_schema = var('artifact_schema', target.schema) %}
{% set tracking_database = target.database %}
{% set monitor_start_date = var('model_monitor_start_date', (modules.datetime.datetime.now() - modules.datetime.timedelta(days=30)).strftime('%Y-%m-%d')) %}
{% set bigquery_jobs_table = var('bigquery_jobs_table') %}

with jobs_with_metadata as (
  select 
    jobs.job_id,
    jobs.total_bytes_billed,
    jobs.total_slot_ms,
    jobs.total_bytes_processed,
    jobs.cache_hit,
    jobs.creation_time,
    jobs.start_time,
    jobs.end_time,
    jobs.reservation_id,
    json_extract_scalar(
      regexp_extract(jobs.query, r'/\* (.*?) \*/', 1),
      '$.dbt_cloud_job_id'
    ) as extracted_dbt_cloud_job_id,
    json_extract_scalar(
      regexp_extract(jobs.query, r'/\* (.*?) \*/', 1),
      '$.dbt_cloud_run_id'
    ) as extracted_dbt_cloud_run_id,
    json_extract_scalar(
      regexp_extract(jobs.query, r'/\* (.*?) \*/', 1),
      '$.node_name'
    ) as extracted_node_name,
    json_extract_scalar(
      regexp_extract(jobs.query, r'/\* (.*?) \*/', 1),
      '$.invocation_id'
    ) as extracted_invocation_id
  from `{{ bigquery_jobs_table }}` as jobs
  where jobs.job_type = 'QUERY'
    and jobs.creation_time >= timestamp('{{ monitor_start_date }}')
    and jobs.destination_table.table_id != '{{ tracking_table }}'
    and jobs.project_id = '{{ tracking_database }}'
)

select 
  jobs.job_id as query_id,
  dbt.run_started_at,
  dbt.model_name,
  dbt.model_package,
  dbt.dbt_cloud_job_id,
  dbt.dbt_cloud_run_id,
  dbt.execution_time,
  dbt.status,
  dbt.invocation_id,
  dbt.dbt_version,
 
  -- Cost information
  jobs.reservation_id,
  jobs.total_slot_ms / 1000 / 60 as slot_minutes,
  SAFE_DIVIDE(jobs.total_slot_ms,(TIMESTAMP_DIFF(jobs.end_time, jobs.start_time, MILLISECOND))) AS job_avg_slots,
  jobs.total_bytes_billed,
  jobs.total_slot_ms,
  jobs.total_bytes_processed,

  -- Query metrics
  jobs.cache_hit,
  jobs.creation_time as query_creation_time,
  jobs.start_time as query_start_time,
  jobs.end_time as query_end_time,

from {{ dbt_model_build_reporter.get_tracking_table_fqn() }} as dbt

inner join jobs_with_metadata as jobs
   on jobs.extracted_dbt_cloud_run_id = dbt.dbt_cloud_run_id
  and jobs.extracted_node_name = dbt.model_name
  and jobs.extracted_invocation_id = dbt.invocation_id
  and jobs.creation_time >= timestamp(dbt.run_started_at)
  and jobs.creation_time <= dbt.insert_timestamp

where dbt.dbt_cloud_job_id is not null
  and dbt.dbt_cloud_job_id != 'none'
  and dbt.model_name != 'model_queries'
