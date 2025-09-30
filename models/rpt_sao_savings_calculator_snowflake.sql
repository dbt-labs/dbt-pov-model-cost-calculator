{{ config(
    enabled=dbt_model_build_reporter.is_adapter_type('snowflake'),
    materialized='table',
    alias='rpt_sao_savings_calculator'
) }}

-- Savings calculator for Snowflake dbt models that were reused
-- This model calculates the cost savings from models that were not run because they were "reused"
-- by aggregating historical cost data and joining with reused model executions

with model_queries as (
  select
    model_name,
    model_package,

    -- Cost aggregations
    avg(credits_attributed_compute) as avg_run_credits,
    max(credits_attributed_compute) as max_run_credits,
    sum(credits_attributed_compute) as total_credits,

    avg(attributed_compute_cost) as avg_run_compute_cost,
    max(attributed_compute_cost) as max_run_compute_cost,
    sum(attributed_compute_cost) as total_compute_cost,

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
      model_package,
      dbt_cloud_run_id,

      sum(credits_attributed_compute) as credits_attributed_compute,
      sum(attributed_compute_cost) as attributed_compute_cost,
      avg(execution_time) as execution_time,
      sum(gb_scanned) as gb_scanned
    from {{ ref('fct_model_queries_snowflake') }}

    group by 1, 2, 3
  )
  group by 1, 2
),

reused_models as (
  select
    model_name,
    model_package,
    count(*) as reuse_count,
    count(distinct dbt_cloud_run_id) as unique_runs_reused,
  from {{ dbt_model_build_reporter.get_tracking_table_fqn() }}
  where status = 'reused'
  group by 1, 2
)

select
  reused_models.model_name,
  reused_models.model_package,

  -- Reuse metrics
  reused_models.reuse_count,
  reused_models.unique_runs_reused,

  -- Historical cost metrics (what it would have cost if not reused)
  model_queries.avg_run_credits,
  model_queries.max_run_credits,
  model_queries.total_credits,

  model_queries.avg_run_compute_cost,
  model_queries.max_run_compute_cost,
  model_queries.total_compute_cost,

  -- Query and execution metrics
  model_queries.total_query_count,
  model_queries.total_run_count,
  model_queries.avg_execution_time_seconds,
  model_queries.max_execution_time_seconds,
  model_queries.avg_gb_scanned,
  model_queries.max_gb_scanned,

  -- Calculated savings metrics
  reused_models.reuse_count * model_queries.avg_run_credits as estimated_credits_saved,
  reused_models.reuse_count * model_queries.avg_run_compute_cost as estimated_cost_saved_usd,

  -- Additional savings insights
  case
    when model_queries.total_run_count > 0
    then round(reused_models.reuse_count * 100.0 / (reused_models.reuse_count + model_queries.total_run_count), 2)
    else 100.0
  end as reuse_rate_percent,

  -- Cost efficiency metrics
  case
    when reused_models.reuse_count > 0
    then round(model_queries.avg_run_compute_cost / reused_models.reuse_count, 4)
    else 0
  end as avg_cost_saved_per_reuse_usd

from reused_models

left join model_queries
  on model_queries.model_name = reused_models.model_name
 and model_queries.model_package = reused_models.model_package

order by estimated_cost_saved_usd desc nulls last
