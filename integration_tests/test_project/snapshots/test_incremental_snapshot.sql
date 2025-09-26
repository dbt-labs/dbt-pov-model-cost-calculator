{% snapshot test_incremental_snapshot %}

  {{
    config(
      target_schema='snapshots',
      unique_key='id',
      strategy='check',
      check_cols=['name', 'id'],
      enabled=dbt_model_build_reporter.is_adapter_type('snowflake')
    )
  }}

  select * from {{ ref('test_incremental_model') }}

{% endsnapshot %}
