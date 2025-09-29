{% snapshot test_incremental_snapshot %}

  {{
    config(
      target_schema='snapshots',
      unique_key='id',
      strategy='check',
      check_cols=['name', 'id'],
      enabled=dbt_pov_model_cost_calculator.is_adapter_type('snowflake')
    )
  }}

  select * from {{ ref('test_incremental_model') }}

{% endsnapshot %}
