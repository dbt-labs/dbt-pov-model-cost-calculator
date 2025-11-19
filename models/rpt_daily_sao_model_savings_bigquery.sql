{{ config(
    enabled=dbt_pov_model_cost_calculator.is_adapter_type('bigquery'),
    materialized='view',
    alias='rpt_daily_sao_model_savings'
) }}

-- Savings calculator for BigQuery dbt models that were reused
-- This model calculates the cost savings from models that were not run because they were "reused"
-- by aggregating historical cost data and joining with reused model executions
--
-- Time Dimension: Results are grouped by date to show savings trends over time
-- This allows for time-series analysis of reuse patterns and cost savings
--
-- BigQuery Pricing: Handles both on-demand ($6.25/TiB default) and slot-based pricing

{% set bigquery_on_demand_price_per_tib = var('bigquery_on_demand_price_per_tib', 6.25) %}
{% set bigquery_slot_ms_per_hour = var('bigquery_slot_ms_per_hour', 0.04) %}

with model_queries as (
  select
    model_name,
    relation_name,
    model_package,

    -- On-demand cost aggregations (bytes billed)
    avg(on_demand_cost) as avg_run_on_demand_cost,
    max(on_demand_cost) as max_run_on_demand_cost,
    sum(on_demand_cost) as total_run_on_demand_cost,

    -- Capacity cost aggregations (slot hours)
    avg(capacity_cost) as avg_run_capacity_cost,
    max(capacity_cost) as max_run_capacity_cost,
    sum(capacity_cost) as total_run_capacity_cost,

    -- Slot usage aggregations
    avg(slot_minutes) as avg_run_slot_minutes,
    max(slot_minutes) as max_run_slot_minutes,
    sum(slot_minutes) as total_run_slot_minutes,
    avg(job_avg_slots) as avg_slots_per_query,
    max(job_avg_slots) as max_slots_per_query,

    -- Data processing metrics
    avg(total_bytes_billed) as avg_bytes_billed,
    max(total_bytes_billed) as max_bytes_billed,
    sum(total_bytes_billed) as total_bytes_billed,
    avg(total_bytes_processed) as avg_bytes_processed,
    max(total_bytes_processed) as max_bytes_processed,

    -- Query count metrics
    count(*) as total_query_count,
    count(distinct dbt_cloud_run_id) as total_run_count,

    -- Additional metrics for context
    avg(execution_time) as avg_execution_time_seconds,
    max(execution_time) as max_execution_time_seconds

  from (
    select
      model_name,
      relation_name,
      model_package,
      dbt_cloud_run_id,

      -- Calculate on-demand cost per query
      -- Convert bytes to TiB (1 TiB = 1024^4 bytes) and multiply by price
      (total_bytes_billed / pow(1024, 4)) * {{ bigquery_on_demand_price_per_tib }} as on_demand_cost,
      (total_slot_ms / 3600000) * {{ bigquery_slot_ms_per_hour }} as capacity_cost,
      slot_minutes,
      job_avg_slots,
      total_bytes_billed,
      total_bytes_processed,
      execution_time
    from {{ ref('fct_model_queries_bigquery') }}
  )
  group by 1, 2, 3
),

reused_models as (
  select
    dbt_models.model_name,
    dbt_models.relation_name,
    dbt_models.model_package,
    date(dbt_models.run_started_at) as reuse_date,
    job_runs.dbt_cloud_environment_id,
    job_runs.dbt_cloud_project_id,
    count(1) as reuse_count,
    count(distinct dbt_models.dbt_cloud_run_id) as unique_runs_reused
  from {{ dbt_pov_model_cost_calculator.get_tracking_table_fqn() }} as dbt_models
  left join {{ ref('deduplicated_job_runs') }} as job_runs
    on job_runs.dbt_cloud_run_id = dbt_models.dbt_cloud_run_id
  where dbt_models.status = 'reused'
  group by 1, 2, 3, 4, 5, 6
)

select
  reused_models.model_name,
  reused_models.relation_name,
  reused_models.model_package,
  reused_models.reuse_date,
  reused_models.dbt_cloud_environment_id,
  reused_models.dbt_cloud_project_id,

  -- Reuse metrics
  reused_models.reuse_count,
  reused_models.unique_runs_reused,

  -- Historical on-demand cost metrics
  model_queries.avg_run_on_demand_cost,
  model_queries.max_run_on_demand_cost,
  model_queries.total_run_on_demand_cost,

  -- Historical on-demand cost metrics
  model_queries.avg_run_capacity_cost,
  model_queries.max_run_capacity_cost,
  model_queries.total_run_capacity_cost,

  -- Historical slot usage metrics
  model_queries.avg_run_slot_minutes,
  model_queries.max_run_slot_minutes,
  model_queries.total_run_slot_minutes,
  model_queries.avg_slots_per_query,
  model_queries.max_slots_per_query,

  -- Data processing metrics
  model_queries.avg_bytes_billed,
  model_queries.max_bytes_billed,
  model_queries.total_bytes_billed,
  model_queries.avg_bytes_processed,
  model_queries.max_bytes_processed,

  -- Query and execution metrics
  model_queries.total_query_count,
  model_queries.total_run_count,
  model_queries.avg_execution_time_seconds,
  model_queries.max_execution_time_seconds,

  -- Calculated on-demand savings metrics
  reused_models.reuse_count * model_queries.avg_run_on_demand_cost as estimated_on_demand_cost_saved_usd,

  -- Calculated slot usage savings
  reused_models.reuse_count * model_queries.avg_run_slot_minutes as estimated_slot_minutes_saved,

  -- Data processing savings
  reused_models.reuse_count * model_queries.avg_bytes_billed as estimated_bytes_billed_saved,

  -- Execution time savings
  reused_models.reuse_count * model_queries.avg_execution_time_seconds as estimated_execution_time_saved_seconds,

  -- Additional savings insights
  case
    when model_queries.total_run_count > 0
    then round(reused_models.reuse_count * 100.0 / (reused_models.reuse_count + model_queries.total_run_count), 2)
    else 100.0
  end as reuse_rate_percent,

  -- Cost efficiency metrics (on-demand)
  case
    when reused_models.reuse_count > 0
    then round(model_queries.avg_run_on_demand_cost / reused_models.reuse_count, 4)
    else 0
  end as avg_on_demand_cost_saved_per_reuse_usd,

  -- Slot efficiency metrics
  case
    when reused_models.reuse_count > 0
    then round(model_queries.avg_run_slot_minutes / reused_models.reuse_count, 4)
    else 0
  end as avg_slot_minutes_saved_per_reuse

from reused_models

left join model_queries
  on model_queries.model_name = reused_models.model_name
 and coalesce(model_queries.relation_name, '') = coalesce(reused_models.relation_name, '')
 and model_queries.model_package = reused_models.model_package
