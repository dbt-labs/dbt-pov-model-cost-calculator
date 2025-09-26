{{ config(
    materialized='view',
    tags=['integration_test']
) }}

-- Test view model to validate view materialization tracking
select 
    2 as id,
    'test_view' as name,
    current_timestamp as created_at

