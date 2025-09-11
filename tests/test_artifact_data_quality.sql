-- Test to ensure data quality in the artifact table
select 
  count(*) as total_records,
  count(distinct model_name) as unique_models,
  count(distinct invocation_id) as unique_invocations,
  count(case when status = 'success' then 1 end) as successful_executions,
  count(case when status = 'error' then 1 end) as failed_executions,
  count(case when status = 'skipped' then 1 end) as skipped_executions,
  min(insert_timestamp) as earliest_record,
  max(insert_timestamp) as latest_record
from {{ var('artifact_table', 'dbt_model_executions') }};

