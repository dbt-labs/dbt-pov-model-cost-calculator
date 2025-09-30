{{ config(
    materialized='incremental',
    unique_key='id',
    tags=['integration_test']
) }}

-- Test incremental model to validate incremental materialization tracking
select
    id,
    name,
    created_at

from {{ ref('test_basic_model') }}

{% if is_incremental() %}
    where created_at > (select max(created_at) from {{ this }})
{% endif %}
