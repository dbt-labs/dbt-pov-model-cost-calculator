{% snapshot test_incremental_snapshot %}

  {{
    config(
      target_schema='snapshots',
      unique_key='id',
      strategy='check',
      check_cols=['name', 'value'],
    )
  }}

  select * from {{ ref('test_incremental_model') }}

{% endsnapshot %}
