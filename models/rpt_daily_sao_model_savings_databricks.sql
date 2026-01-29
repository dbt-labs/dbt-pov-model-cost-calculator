{{ config(
    enabled=dbt_pov_model_cost_calculator.is_enabled('databricks'),
    materialized='view',
    alias='rpt_daily_sao_model_savings'
) }}

-- Savings calculator for Databricks dbt models that were reused
-- This model calculates the cost savings from models that were not run because they were "reused"
-- by aggregating historical cost data and joining with reused model executions
--
-- Time Dimension: Results are grouped by date to show savings trends over time
-- This allows for time-series analysis of reuse patterns and cost savings

with model_queries as (
  select
    model_name,
    relation_name,
    model_package,

    -- Cost aggregations (DBUs and USD)
    avg(dbus_consumed) as avg_run_dbus,
    max(dbus_consumed) as max_run_dbus,
    sum(dbus_consumed) as total_run_dbus,

    avg(estimated_cost_usd) as avg_run_cost,
    max(estimated_cost_usd) as max_run_cost,
    sum(estimated_cost_usd) as total_run_cost,

    -- Query count metrics
    count(*) as total_query_count,
    count(distinct dbt_cloud_run_id) as total_run_count,

    -- Additional metrics for context
    avg(execution_time) as avg_execution_time_seconds,
    max(execution_time) as max_execution_time_seconds,
    avg(gb_read) as avg_gb_read,
    max(gb_read) as max_gb_read

  from (
    select
      model_name,
      relation_name,
      model_package,
      dbt_cloud_run_id,

      sum(dbus_consumed) as dbus_consumed,
      sum(estimated_cost_usd) as estimated_cost_usd,
      avg(execution_time) as execution_time,
      sum(gb_read) as gb_read
    from {{ ref('fct_model_queries_databricks') }}

    group by 1, 2, 3, 4
  )
  group by 1, 2, 3
),

dbt_execution_metadata as (
  select
    dbt_models.model_name,
    dbt_models.relation_name,
    dbt_models.model_package,
    date(dbt_models.run_started_at) as reuse_date,
    job_runs.dbt_cloud_environment_id,
    job_runs.dbt_cloud_project_id,
    sum(case when dbt_models.status = 'reused' then 1 else 0 end) as reuse_count,
    sum(case when dbt_models.status in ('success','error') then 1 else 0 end) as execute_count
  from {{ ref('model_tracking_table') }} as dbt_models
  left join {{ ref('deduplicated_job_runs') }} as job_runs
    on job_runs.dbt_cloud_run_id = dbt_models.dbt_cloud_run_id
  group by 1, 2, 3, 4, 5, 6
)

select
  dbt_execution_metadata.model_name,
  dbt_execution_metadata.relation_name,
  dbt_execution_metadata.model_package,
  dbt_execution_metadata.reuse_date,
  dbt_execution_metadata.dbt_cloud_environment_id,
  dbt_execution_metadata.dbt_cloud_project_id,

  -- Reuse metrics
  dbt_execution_metadata.reuse_count,
  dbt_execution_metadata.execute_count,

  -- Historical cost metrics (what it would have cost if not reused)
  model_queries.avg_run_dbus,
  model_queries.max_run_dbus,
  model_queries.total_run_dbus,

  model_queries.avg_run_cost,
  model_queries.max_run_cost,
  model_queries.total_run_cost,

  -- Query and execution metrics
  model_queries.total_query_count,
  model_queries.total_run_count,
  model_queries.avg_execution_time_seconds,
  model_queries.max_execution_time_seconds,
  model_queries.avg_gb_read,
  model_queries.max_gb_read,

  -- Calculated savings metrics
  dbt_execution_metadata.reuse_count * model_queries.avg_run_dbus as estimated_dbus_saved,
  dbt_execution_metadata.reuse_count * model_queries.avg_run_cost as estimated_cost_saved_usd,

     -- Calculated cost metrics
  dbt_execution_metadata.execute_count * model_queries.avg_run_dbus as estimated_dbus_used,
  dbt_execution_metadata.execute_count * model_queries.avg_run_cost as estimated_cost_spent_usd,
  
  -- Additional savings insights
  case
    when dbt_execution_metadata.execute_count > 0
    then round(dbt_execution_metadata.reuse_count * 100.0 / (dbt_execution_metadata.reuse_count + dbt_execution_metadata.execute_count), 2)
    else 100.0
  end as reuse_rate_percent,

  -- Cost efficiency metrics
  case
    when dbt_execution_metadata.reuse_count > 0
    then round(model_queries.avg_run_cost / dbt_execution_metadata.reuse_count, 4)
    else 0
  end as avg_cost_saved_per_reuse_usd

from dbt_execution_metadata

left join model_queries
  on model_queries.model_name = dbt_execution_metadata.model_name
 and model_queries.model_package = dbt_execution_metadata.model_package
 and model_queries.relation_name = dbt_execution_metadata.relation_name
