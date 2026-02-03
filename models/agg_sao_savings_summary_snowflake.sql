{{ config(
    enabled=dbt_pov_model_cost_calculator.is_enabled('snowflake'),
    materialized='view',
    alias='agg_sao_savings_summary'
) }}

-- Savings summary for Snowflake dbt models that were reused
-- This model creates an aggregate, single row summary of the cost savings from fct_model_queries_snowflake
-- Run for specific date range with below command, otherwise default will run for the last full 7 days
-- dbt run --select +agg_sao_savings_summary_snowflake --vars '{"summary_start_date": "2025-12-04", "summary_end_date": "2025-12-11"}'

{% set summary_start_date = var('summary_start_date', (modules.datetime.datetime.now() - modules.datetime.timedelta(days=8)).strftime('%Y-%m-%d')) %}
{% set summary_end_date = var('summary_end_date', (modules.datetime.datetime.now() - modules.datetime.timedelta(days=1)).strftime('%Y-%m-%d')) %}

with base as (
    select
        reuse_date,
        relation_name,
        estimated_cost_saved_usd,
        estimated_cost_spent_usd,
        reuse_count,
        execute_count
    from {{ ref('rpt_daily_sao_model_savings_snowflake') }}
    where reuse_date between '{{ summary_start_date }}' and '{{ summary_end_date }}'
),
aggregated as (
    select
        min(reuse_date) as summary_start_date,
        max(reuse_date) as summary_end_date,
        sum(estimated_cost_saved_usd) as total_estimated_cost_saved,
        sum(estimated_cost_spent_usd) as total_estimated_cost_spent,
        -- Models
        sum(case when relation_name like 'model.%' then reuse_count else 0 end) as total_reused_models,
        sum(case when relation_name like 'model.%' then execute_count else 0 end) as total_executed_models,
        sum(case when relation_name like 'model.%' then estimated_cost_saved_usd else 0 end) as total_reused_model_cost_savings,
        -- Tests
        sum(case when relation_name like 'test.%' then reuse_count else 0 end) as total_reused_tests,
        sum(case when relation_name like 'test.%' then execute_count else 0 end) as total_executed_tests,
        sum(case when relation_name like 'test.%' then estimated_cost_saved_usd else 0 end) as total_reused_test_cost_savings
    from base
)

select
    -- Summary Date Range
    summary_start_date,
    summary_end_date,
    -- Total Savings Metrics
    round(total_estimated_cost_saved, 2) as total_reused_cost_savings,
    round(total_estimated_cost_spent, 2) as total_cost_spent,
    round((total_estimated_cost_saved / nullif(total_estimated_cost_saved + total_estimated_cost_spent, 0)) * 100, 2) as perc_cost_savings,
    -- Model Metrics
    total_reused_models,
    total_executed_models,
    total_reused_models + total_executed_models as total_attempted_models,
    round((total_reused_models / nullif(total_reused_models + total_executed_models, 0)) * 100, 2) as perc_reused_models,
    round(total_reused_model_cost_savings, 2) as total_reused_model_cost_savings,
    -- Test Metrics
    total_reused_tests,
    total_executed_tests,
    total_reused_tests + total_executed_tests as total_attempted_tests,
    round((total_reused_tests / nullif(total_reused_tests + total_executed_tests, 0)) * 100, 2) as perc_reused_tests,
    round(total_reused_test_cost_savings, 2) as total_reused_test_cost_savings
from aggregated