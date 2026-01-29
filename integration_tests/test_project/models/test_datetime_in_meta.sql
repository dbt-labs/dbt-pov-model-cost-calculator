{{ config(
    materialized='table',
    tags=['integration_test', 'datetime_bug'],
    meta = {
        'owner': 'data-team',
        'created_at': modules.datetime.datetime.now()
    }
) }}

-- Test model to reproduce datetime JSON serialization bug
-- https://github.com/dbt-labs/dbt-pov-model-cost-calculator/issues/60
--
-- This model has a raw datetime object in meta (not converted to string),
-- which causes "Object of type datetime is not JSON serialisable" error
-- in the record_dbt_project_models macro when it tries to call tojson()
select
    1 as id,
    'datetime_in_meta_test' as name,
    current_timestamp as created_at
