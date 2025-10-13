{{
  config(
    materialized='ephemeral'
  )
}}

-- Deduplicate job runs to handle multiple records with the same dbt_cloud_run_id
-- This ephemeral model is used by all rpt_daily_sao_model_savings reports
select
  dbt_cloud_run_id,
  dbt_cloud_environment_id,
  dbt_cloud_project_id
from {{ dbt_pov_model_cost_calculator.get_job_runs_tracking_table_fqn() }}
group by 1, 2, 3
