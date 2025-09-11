-- Test to ensure the artifact table exists and has the expected structure
select 
  column_name,
  data_type,
  is_nullable
from information_schema.columns
where table_schema = '{{ var("artifact_schema", target.schema) }}'
  and table_name = '{{ var("artifact_table", "dbt_model_executions") }}'
order by ordinal_position;

