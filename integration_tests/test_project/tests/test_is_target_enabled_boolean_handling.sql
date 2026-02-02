-- Test that is_target_enabled() correctly handles boolean values
-- This test validates the macro's boolean handling logic
--
-- The macro should:
-- 1. Return True when the var is not set (default behavior)
-- 2. Handle both boolean true/True and string 'true'/'True' correctly
--
-- This test will FAIL (return rows) if the macro returns an unexpected value

-- Test the default value (when enable_cost_savings_calculator is not set)
-- Per the macro, the default should be true
{% set default_result = dbt_pov_model_cost_calculator.is_target_enabled() %}

-- The macro is expected to return a boolean true value
-- If the result is not exactly equal to boolean true, this test will fail
select
    'is_target_enabled_default_not_true' as test_case,
    '{{ default_result }}' as actual_value,
    'true' as expected_value
where not ({{ default_result }} = true)
