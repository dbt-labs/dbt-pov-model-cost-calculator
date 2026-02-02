-- Test that is_target_enabled() returns True by default when enable_cost_savings_calculator is not set
-- This test validates the fix for the issue where models would not be enabled by default
-- because the macro used lowercase 'true' instead of Python-style 'True'

-- This test will FAIL (return rows) if is_target_enabled() does NOT return true by default
-- A passing test returns zero rows

{% set result = dbt_pov_model_cost_calculator.is_target_enabled() %}

select 1 as failure_indicator
where {{ result }} != true
