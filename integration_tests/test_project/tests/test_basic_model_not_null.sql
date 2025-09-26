-- Test that the basic model has no null values in the id column
select *
from {{ ref('test_basic_model') }}
where id is null
