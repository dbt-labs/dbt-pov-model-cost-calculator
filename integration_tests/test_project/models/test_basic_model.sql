{{ config(
    materialized='table',
    tags=['integration_test'],
    meta = {
    'test_meta': "submitted_at '" ~ modules.datetime.datetime.now().strftime('%Y-%m-%d')~"'",
    }
) }}

-- Basic test model to validate dbt_model_build_logger functionality
select
    1 as id,
    'test_model' as name,
    current_timestamp as created_at
