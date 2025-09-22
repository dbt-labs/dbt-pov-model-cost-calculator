{{ config(
    enabled=dbt_model_build_reporter.is_adapter_type('bigquery'),
    materialized='view'
) }}

{% set tracking_table = var('artifact_table', 'dbt_model_executions') %}
{% set tracking_schema = var('artifact_schema', target.schema) %}
{% set tracking_database = target.database %}
{% set monitor_start_date = var('model_monitor_start_date', (modules.datetime.datetime.now() - modules.datetime.timedelta(days=30)).strftime('%Y-%m-%d')) %}
{% set bigquery_jobs_table = var('bigquery_jobs_table') %}
{% set gcp_billing_project_id = var('gcp_billing_project_id', target.database) %}
{% set bigquery_region = var('bigquery_region', 'us') %}
{% set bigquery_slot_hour_cost = var('bigquery_slot_hour_cost', 0.04) %}

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
),

-- Get reservation details for each job
jobs_with_reservations as (
  select 
    jobs.*,
    reservations.reservation_name,
    reservations.slot_capacity,
    reservations.ignore_idle_slots,
    reservations.autoscale_max_slots,
    reservations.autoscale_current_slots,
    reservations.cost as reservation_cost
  from jobs_with_metadata as jobs
  left join `{{ gcp_billing_project_id }}.{{ bigquery_region }}.INFORMATION_SCHEMA.RESERVATIONS_TIMELINE` as reservations
    on jobs.reservation_id = reservations.reservation_id
    and reservations.start_time <= jobs.creation_time
    and reservations.end_time >= jobs.creation_time
    and reservations.project_id = '{{ tracking_database }}'
),

-- Calculate total assigned slots and cost per reservation for the monitoring period
-- Based on: https://cloud.google.com/bigquery/docs/information-schema-reservation-timeline
reservation_costs as (
  select 
    reservation_id,
    reservation_name,
    sum(slot_capacity) as total_assigned_slots,
    -- Calculate total cost: total_slots * hours_in_period * hourly_cost
    sum(slot_capacity) * 
    (timestamp_diff(current_timestamp(), timestamp('{{ monitor_start_date }}'), hour)) * 
    {{ bigquery_slot_hour_cost }} as total_reservation_cost_usd,
    min(start_time) as earliest_reservation_start,
    max(end_time) as latest_reservation_end,
    count(*) as reservation_timeline_entries
  from `{{ gcp_billing_project_id }}.{{ bigquery_region }}.INFORMATION_SCHEMA.RESERVATIONS_TIMELINE`
  where start_time >= timestamp('{{ monitor_start_date }}')
    and start_time <= current_timestamp()
    and project_id = '{{ tracking_database }}'
  group by reservation_id, reservation_name
),

-- Calculate total slot usage per reservation for accurate cost allocation
reservation_slot_usage as (
  select 
    reservation_id,
    reservation_name,
    sum(total_slot_ms) as total_slot_ms_per_reservation,
    count(*) as query_count_per_reservation,
    min(creation_time) as earliest_query_time,
    max(creation_time) as latest_query_time
  from jobs_with_reservations
  where reservation_id is not null
  group by reservation_id, reservation_name
),

-- Calculate total slot usage across all queries in the monitoring period
total_slot_usage as (
  select 
    sum(total_slot_ms) as total_slot_ms_all_queries,
    count(distinct reservation_id) as total_reservations_used
  from jobs_with_reservations
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
  jobs.total_slot_ms / 1000 / 60 as slot_minutes,
  jobs.total_bytes_billed / (1024*1024*1024) as gb_billed,
  case 
    when jobs.total_bytes_billed > 0 then 
      (jobs.total_bytes_billed / (1024*1024*1024)) * 5.0  -- $5 per GB for BigQuery
    else 0 
  end as estimated_cost_usd,

  -- Slot capacity cost calculation based on reservation-specific allocation:
  -- cost_per_query = (query_slot_usage / reservation_slot_usage) * calculated_reservation_cost
  case 
    when jobs.reservation_id is not null 
         and res_usage.total_slot_ms_per_reservation > 0 
         and jobs.total_slot_ms > 0 
         and costs.total_reservation_cost_usd > 0 then
      (jobs.total_slot_ms / res_usage.total_slot_ms_per_reservation) * costs.total_reservation_cost_usd
    else 0
  end as slot_capacity_cost_usd,

  -- Reservation information
  jobs.reservation_id,
  jobs.reservation_name,
  jobs.slot_capacity,
  jobs.autoscale_current_slots,
  jobs.ignore_idle_slots,

  -- Additional slot cost metrics
  jobs.total_slot_ms as query_slot_ms,
  slot_usage.total_slot_ms_all_queries,
  slot_usage.total_reservations_used,
  res_usage.total_slot_ms_per_reservation,
  res_usage.query_count_per_reservation,
  costs.total_assigned_slots,
  costs.total_reservation_cost_usd,
  costs.reservation_timeline_entries,
  case 
    when res_usage.total_slot_ms_per_reservation > 0 then
      (jobs.total_slot_ms / res_usage.total_slot_ms_per_reservation) * 100
    else 0
  end as reservation_slot_usage_percentage,
  case 
    when slot_usage.total_slot_ms_all_queries > 0 then
      (jobs.total_slot_ms / slot_usage.total_slot_ms_all_queries) * 100
    else 0
  end as total_slot_usage_percentage,

  -- Query metrics
  jobs.total_bytes_billed,
  jobs.total_slot_ms,
  jobs.total_bytes_processed,
  jobs.cache_hit,
  jobs.creation_time as query_creation_time,
  jobs.start_time as query_start_time,
  jobs.end_time as query_end_time

from {{ tracking_database }}.{{ tracking_schema }}.{{ tracking_table }} as dbt

inner join jobs_with_reservations as jobs
  on jobs.extracted_dbt_cloud_job_id = dbt.dbt_cloud_job_id
  and jobs.extracted_node_name = dbt.model_name
  and jobs.extracted_invocation_id = dbt.invocation_id
  and jobs.creation_time >= timestamp(dbt.run_started_at)
  and jobs.creation_time <= dbt.insert_timestamp

left join reservation_slot_usage as res_usage
  on jobs.reservation_id = res_usage.reservation_id

left join reservation_costs as costs
  on jobs.reservation_id = costs.reservation_id

cross join total_slot_usage as slot_usage

where dbt.dbt_cloud_job_id is not null
  and dbt.dbt_cloud_job_id != 'none'
  and dbt.model_name != 'model_queries'
