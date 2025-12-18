{{ config(
    enabled=dbt_pov_model_cost_calculator.is_enabled('databricks'),
    materialized='view',
    alias='agg_sao_savings_summary'
) }}

-- Savings summary for Databricks dbt models that were reused
-- This model creates an aggregate, single row summary of the cost savings from fct_model_queries_databricks
-- Run for specific date range with below command, otherwise default will run for the last full 7 days
-- dbt run --select +agg_sao_savings_summary_databricks --vars '{"summary_start_date": "2025-12-04", "summary_end_date": "2025-12-11"}'

{% set summary_start_date = var('summary_start_date', (modules.datetime.datetime.now() - modules.datetime.timedelta(days=8)).strftime('%Y-%m-%d')) %}
{% set summary_end_date = var('summary_start_date', (modules.datetime.datetime.now() - modules.datetime.timedelta(days=1)).strftime('%Y-%m-%d')) %}

select
--dates
MIN(reuse_date) as summary_start_date,
MAX(reuse_date) as summary_end_date,
 --model counts
SUM(reuse_count) as total_reused_models,
SUM(execute_count) as total_executed_models,
SUM(reuse_count + execute_count) as total_attempted_models,
ROUND((SUM(reuse_count) / SUM(reuse_count + execute_count)) * 100, 2) as perc_reused_models,
 --model costs
ROUND(SUM(estimated_cost_saved_usd), 2) as total_reused_cost_savings,
ROUND(SUM(estimated_cost_spent_usd), 2) as total_cost_spent,
ROUND((SUM(estimated_cost_saved_usd) / SUM(estimated_cost_saved_usd + estimated_cost_spent_usd)) * 100, 2) as perc_cost_savings
from {{ ref('rpt_daily_sao_model_savings_databricks') }}
where reuse_date between '{{ summary_start_date }}' and '{{ summary_end_date }}'