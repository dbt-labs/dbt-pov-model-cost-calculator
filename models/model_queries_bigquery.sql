{{ config(
    enabled=dbt_model_build_logger.is_adapter_type('bigquery'),
    materialized='view'
) }}

{% set tracking_table = var('artifact_table', 'dbt_model_executions') %}
{% set tracking_schema = var('artifact_schema', target.schema) %}
{% set tracking_database = target.database %}
{% set monitor_start_date = var('model_monitor_start_date', (modules.datetime.datetime.now() - modules.datetime.timedelta(days=30)).strftime('%Y-%m-%d')) %}
{% if target.compute_region %}
    {% set tracking_region = target.compute_region %}
{% else %}
    {% set tracking_region = 'us' %}
{% endif %}

select 
  jobs.job_id as query_id,
  dbt.model_name,
  dbt.model_package,
  dbt.dbt_cloud_job_id,
  dbt.dbt_cloud_run_id,
  dbt.execution_time,
  dbt.status,
  dbt.invocation_id,
  jobs.total_bytes_billed,
  jobs.total_slot_ms,
  jobs.total_bytes_processed,
  jobs.cache_hit,
  jobs.creation_time as query_creation_time,
  jobs.start_time as query_start_time,
  jobs.end_time as query_end_time,
  jobs.total_slot_ms / 1000 / 60 as slot_minutes,
  jobs.total_bytes_billed / (1024*1024*1024) as gb_billed,
  case 
    when jobs.total_bytes_billed > 0 then 
      (jobs.total_bytes_billed / (1024*1024*1024)) * 5.0  -- $5 per GB for BigQuery
    else 0 
  end as estimated_cost_usd

from {{ tracking_database }}.{{ tracking_schema }}.{{ tracking_table }} as dbt
left join `{{ target.project }}.region-{{ tracking_region }}.INFORMATION_SCHEMA.JOBS` as jobs
  on jobs.job_type = 'QUERY'
  and jobs.query like '%' || dbt.model_name || '%'
  and jobs.query like '%"dbt_cloud_job_id": "' || dbt.dbt_cloud_job_id || '",%'
  and jobs.creation_time >= timestamp(dbt.run_started_at)
  and jobs.creation_time <= dbt.insert_timestamp

where dbt.dbt_cloud_job_id is not null
  and dbt.dbt_cloud_job_id != 'none'
  and dbt.model_name != 'model_queries'
  and dbt.status = 'success'
  and jobs.project = '{{ tracking_database }}'
  and jobs.destination_table.table_id != '{{ tracking_table }}'
  and jobs.creation_time >= timestamp('{{ monitor_start_date }}')
