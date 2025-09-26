{% snapshot test_snapshot %}

  {{
    config(
      target_schema='snapshots',
      unique_key='id',
      strategy='timestamp',
      updated_at='created_at',
    )
  }}

  select * from {{ ref('test_basic_model') }}

{% endsnapshot %}
