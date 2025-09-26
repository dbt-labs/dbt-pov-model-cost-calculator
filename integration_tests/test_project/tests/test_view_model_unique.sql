-- Test that the view model has unique values in the id column
select id, count(*) as count
from {{ ref('test_view_model') }}
group by id
having count(*) > 1
