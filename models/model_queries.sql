select 
      jobs.job_id as query_id,  
      dbt.model_name,
      dbt.dbt_cloud_job_id,
      dbt.execution_time,
      jobs.query as query_text,
      jobs.total_bytes_billed,
      jobs.total_slot_ms,
      jobs.total_bytes_processed

from test.dbt_model_executions as dbt
left join `region-us.INFORMATION_SCHEMA.JOBS` as jobs
on
  jobs.job_type = 'QUERY'
  AND jobs.creation_time BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY) AND CURRENT_TIMESTAMP()
  and jobs.query like'%'|| dbt.model_name || '%'
  and jobs.query like'%"dbt_cloud_job_id": "'|| dbt.dbt_cloud_job_id || '",%'
  and jobs.destination_table.table_id <> 'dbt_model_executions'

where dbt.dbt_cloud_job_id is not null
  and dbt.dbt_cloud_job_id <> 'none'
  and dbt.model_name <> 'model_queries'
  