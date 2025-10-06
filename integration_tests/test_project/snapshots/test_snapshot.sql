{% snapshot test_snapshot %}

  {{
    config(
      target_schema='snapshots',
      unique_key='created_at',
      strategy='timestamp',
      updated_at='created_at',
      enabled=dbt_pov_model_cost_calculator.is_adapter_type('snowflake')
    )
  }}

  select id,
         name,
         created_at::timestamp_ntz as created_at
   from {{ ref('test_basic_model') }}

{% endsnapshot %}
