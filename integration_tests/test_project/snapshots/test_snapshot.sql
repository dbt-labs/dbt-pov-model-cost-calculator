{% snapshot test_snapshot %}

  {{
    config(
      target_schema='snapshots',
      unique_key='id',
      strategy='timestamp',
      updated_at='created_at',
      enabled=dbt_model_build_reporter.is_adapter_type('snowflake')
    )
  }}

  select * from {{ ref('test_basic_model') }}

{% endsnapshot %}
