{{ config(
    enabled=dbt_pov_model_cost_calculator.is_adapter_type('snowflake'),
    materialized='view',
    alias='rpt_daily_sao_model_savings'
) }}

-- Savings calculator for Snowflake dbt models that were reused
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

    -- Cost aggregations (compute + cloud services)
    avg(total_credits) as avg_run_credits,
    max(total_credits) as max_run_credits,
    sum(total_credits) as total_run_credits,
    sum(credits_attributed_compute) as total_run_compute_credits,


    avg(query_cost) as avg_run_cost,
    max(query_cost) as max_run_cost,
    sum(query_cost) as total_run_cost,
    sum(attributed_compute_cost) as total_run_compute_cost,

    -- Query count metrics
    count(*) as total_query_count,
    count(distinct dbt_cloud_run_id) as total_run_count,

    -- Additional metrics for context
    avg(execution_time) as avg_execution_time_seconds,
    max(execution_time) as max_execution_time_seconds,
    avg(gb_scanned) as avg_gb_scanned,
    max(gb_scanned) as max_gb_scanned

  from (
    select
      model_name,
      relation_name,
      model_package,
      dbt_cloud_run_id,

      sum(credits_attributed_compute) as credits_attributed_compute,
      sum(zeroifnull(credits_attributed_compute) + zeroifnull(credits_used_cloud_services)) as total_credits,
      sum(attributed_compute_cost) as attributed_compute_cost,
      sum(zeroifnull(attributed_compute_cost) + zeroifnull(cloud_services_cost)) as query_cost,
      avg(execution_time) as execution_time,
      sum(gb_scanned) as gb_scanned
    from {{ ref('fct_model_queries_snowflake') }}

    group by 1, 2, 3, 4
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

  -- Historical cost metrics (what it would have cost if not reused - includes compute + cloud services)
  model_queries.avg_run_credits,
  model_queries.max_run_credits,
  model_queries.total_run_credits,

  model_queries.avg_run_cost,
  model_queries.max_run_cost,
  model_queries.total_run_cost,

  -- Query and execution metrics
  model_queries.total_query_count,
  model_queries.total_run_count,
  model_queries.avg_execution_time_seconds,
  model_queries.max_execution_time_seconds,
  model_queries.avg_gb_scanned,
  model_queries.max_gb_scanned,

  -- Calculated savings metrics
  reused_models.reuse_count * model_queries.avg_run_credits as estimated_credits_saved,
  reused_models.reuse_count * model_queries.avg_run_cost as estimated_cost_saved_usd,

  -- Additional savings insights
  case
    when model_queries.total_run_count > 0
    then round(reused_models.reuse_count * 100.0 / (reused_models.reuse_count + model_queries.total_run_count), 2)
    else 100.0
  end as reuse_rate_percent,

  -- Cost efficiency metrics
  case
    when reused_models.reuse_count > 0
    then round(model_queries.avg_run_cost / reused_models.reuse_count, 4)
    else 0
  end as avg_cost_saved_per_reuse_usd

from reused_models

left join model_queries
  on model_queries.model_name = reused_models.model_name
 and model_queries.model_package = reused_models.model_package
 and model_queries.relation_name = reused_models.relation_name