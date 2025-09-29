{{ config(
    enabled=dbt_pov_model_cost_calculator.is_adapter_type('bigquery'),
    materialized='table',
    alias='rpt_model_cost'
) }}

-- Model run-level cost aggregation report for BigQuery
-- Aggregates data from fct_model_queries_bigquery to provide cost insights at the model/dbt_run level
-- This provides a time series view of model costs and performance over time
-- 
-- Pricing: $6.25 per TiB (tebibyte) for on-demand queries in US regions
-- Reference: https://cloud.google.com/bigquery/pricing?hl=en#on_demand_pricing
-- Note: Pricing varies by region - update the pricing constant below for different regions

{% set bigquery_on_demand_price_per_tib = var('bigquery_on_demand_price_per_tib', 6.25) %}

with model_run_aggregations as (
  select 
    model_name,
    model_package,
    dbt_version,
    dbt_cloud_job_id,
    dbt_cloud_run_id,
    run_started_at,
    invocation_id,
    
    -- Execution metrics
    count(*) as total_executions,
    
    -- Success/failure metrics
    sum(case when status = 'success' then 1 else 0 end) as successful_executions,
    sum(case when status = 'error' then 1 else 0 end) as failed_executions,
    round(
      sum(case when status = 'success' then 1 else 0 end) * 100.0 / count(*), 
      2
    ) as success_rate_percent,
    
    -- Time metrics
    avg(execution_time) as avg_execution_time_seconds,
    max(execution_time) as max_execution_time_seconds,
    min(execution_time) as min_execution_time_seconds,
    
    -- Slot usage metrics
    sum(slot_minutes) as total_slot_minutes,
    avg(slot_minutes) as avg_slot_minutes_per_execution,
    max(slot_minutes) as max_slot_minutes_per_execution,
    sum(total_slot_ms) as total_slot_ms,
    avg(job_avg_slots) as avg_slots_per_execution,
    max(job_avg_slots) as max_slots_per_execution,
    
    -- Data processing metrics
    sum(total_bytes_billed) as total_bytes_billed,
    sum(total_bytes_processed) as total_bytes_processed,
    avg(total_bytes_billed) as avg_bytes_billed_per_execution,
    avg(total_bytes_processed) as avg_bytes_processed_per_execution

  from {{ ref('fct_model_queries_bigquery') }}
  group by 
    model_name,
    model_package,
    dbt_version,
    dbt_cloud_job_id,
    dbt_cloud_run_id,
    run_started_at,
    invocation_id
),

-- Calculate cost metrics
cost_calculations as (
  select 
    *,
    
    -- On-demand cost calculation (configurable price per TiB processed)
    -- Convert bytes to TiB (tebibyte) and multiply by configurable price
    -- 1 TiB = 1024^4 bytes
    round(
      (total_bytes_billed / power(1024, 4)) * {{ bigquery_on_demand_price_per_tib }}, 
      4
    ) as on_demand_cost_usd,
    
    -- Average on-demand cost per execution
    round(
      ((total_bytes_billed / power(1024, 4)) * {{ bigquery_on_demand_price_per_tib }}) / nullif(total_executions, 0), 
      4
    ) as avg_on_demand_cost_per_execution_usd,
    
    -- Slot capacity cost (placeholder - would need reservation cost data)
    -- This would be calculated based on actual reservation costs
    0.0 as slot_capacity_cost_usd,
    
    -- Total estimated cost (on-demand + slot capacity)
    round(
      (total_bytes_billed / power(1024, 4)) * {{ bigquery_on_demand_price_per_tib }} + 0.0, 
      4
    ) as total_estimated_cost_usd,
    
    -- Cost per successful execution
    round(
      ((total_bytes_billed / power(1024, 4)) * {{ bigquery_on_demand_price_per_tib }}) / nullif(successful_executions, 0), 
      4
    ) as cost_per_successful_execution_usd

  from model_run_aggregations
)

select 
  model_name,
  model_package,
  dbt_version,
  dbt_cloud_job_id,
  dbt_cloud_run_id,
  run_started_at,
  invocation_id,
  
  -- Execution summary
  total_executions,
  successful_executions,
  failed_executions,
  success_rate_percent,
  
  -- Time metrics
  avg_execution_time_seconds,
  max_execution_time_seconds,
  min_execution_time_seconds,
  
  -- Slot usage metrics
  total_slot_minutes,
  avg_slot_minutes_per_execution,
  max_slot_minutes_per_execution,
  total_slot_ms,
  avg_slots_per_execution,
  max_slots_per_execution,
  
  -- Data processing metrics
  total_bytes_billed,
  total_bytes_processed,
  avg_bytes_billed_per_execution,
  avg_bytes_processed_per_execution,
  
  -- Cost metrics
  on_demand_cost_usd,
  avg_on_demand_cost_per_execution_usd,
  slot_capacity_cost_usd,
  total_estimated_cost_usd,
  cost_per_successful_execution_usd

from cost_calculations
order by run_started_at desc, model_name, total_estimated_cost_usd desc