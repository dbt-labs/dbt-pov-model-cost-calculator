{% snapshot test_snapshot %}

  {{
    config(
      target_schema='snapshots',
      unique_key='id',
      strategy='timestamp',
      updated_at='created_at',
      enabled=dbt_pov_model_cost_calculator.is_adapter_type('snowflake')
    )
  }}

  select * from {{ ref('test_basic_model') }}

{% endsnapshot %}
