{{ config(
    enabled=dbt_pov_model_cost_calculator.is_enabled('databricks'),
    materialized='view',
    alias='fct_dbt_model_queries'
) }}

{% set tracking_table = var('artifact_table', 'dbt_model_executions') %}
{% set tracking_schema = var('artifact_schema', target.schema) %}
{% set tracking_database = target.database %}
{% set monitor_start_date = var('model_monitor_start_date', (modules.datetime.datetime.now() - modules.datetime.timedelta(days=30)).strftime('%Y-%m-%d')) %}
{% set databricks_query_history_table = var('databricks_query_history_table', 'system.query.history') %}
{% set databricks_billing_usage_table = var('databricks_billing_usage_table', 'system.billing.usage') %}
{% set databricks_billing_prices_table = var('databricks_billing_prices_table', 'system.billing.list_prices') %}

with query_with_compute as (
  select
    qh.statement_id,
    qh.executed_by,
    qh.client_application,
    qh.start_time,
    qh.end_time,
    qh.execution_duration_ms,
    qh.execution_duration_ms / 1000 as execution_seconds,
    qh.execution_duration_ms / 3600000 as execution_hours,
    qh.compute.cluster_id,
    qh.compute.warehouse_id,
    qh.compute.type as compute_type,
    qh.workspace_id,
    qh.read_rows,
    qh.read_bytes,
    qh.produced_rows,
    qh.written_bytes,
    left(qh.statement_text, 200) as query_preview,
    qh.statement_text as query_text,
    from_json(
      regexp_extract(qh.statement_text, '/\\* (.*?) \\*/', 1),
      'STRUCT<app:STRING,
              dbt_version:STRING,
              dbt_databricks_version:STRING,
              databricks_sql_connector_version:STRING,
              profile_name:STRING,
              target_name:STRING,
              node_id:STRING,
              node_name:STRING,
              dbt_cloud_job_id:STRING,
              dbt_cloud_run_id:STRING,
              invocation_id:STRING,
              connection_name:STRING
            >'
    ) as query_metadata
  from {{ databricks_query_history_table }} qh
  where qh.start_time >= '{{ monitor_start_date }}'
    and qh.execution_status = 'FINISHED'
),

-- Calculate total query execution time per billing period per compute resource
total_query_time_per_billing_period as (
  select
    bu.record_id,
    bu.workspace_id,
    coalesce(bu.usage_metadata.cluster_id, bu.usage_metadata.warehouse_id) as compute_resource_id,
    bu.usage_start_time,
    bu.usage_end_time,
    bu.usage_quantity,
    bu.sku_name,
    bu.billing_origin_product,
    -- Sum of query execution time that actually overlaps with this billing period
    sum(
      greatest(
        timestampdiff(second,
          greatest(qwc.start_time, bu.usage_start_time),  -- Later of query start or billing start
          least(qwc.end_time, bu.usage_end_time)         -- Earlier of query end or billing end
        ),
        0
      )
    ) as total_query_execution_seconds
  from {{ databricks_billing_usage_table }} bu
  left join query_with_compute qwc on bu.workspace_id = qwc.workspace_id
    and coalesce(bu.usage_metadata.cluster_id, bu.usage_metadata.warehouse_id) = coalesce(qwc.cluster_id, qwc.warehouse_id)
    -- Query overlaps with billing period (any overlap, not just fully contained)
    and qwc.start_time < bu.usage_end_time
    and qwc.end_time > bu.usage_start_time
  where bu.usage_start_time >= '{{ monitor_start_date }}'
  group by bu.record_id, bu.workspace_id, compute_resource_id, bu.usage_start_time, bu.usage_end_time, bu.usage_quantity, bu.sku_name, bu.billing_origin_product
),

-- Calculate proportional DBU allocation per query
query_dbu_allocation as (
  select
    qwc.statement_id,
    tqt.sku_name,
    -- Proportional DBU allocation: (total_dbus * this_query_overlap_time / total_query_time_in_period)
    case
      when tqt.total_query_execution_seconds > 0 then
        tqt.usage_quantity *
        greatest(
          timestampdiff(second,
            greatest(qwc.start_time, tqt.usage_start_time),  -- Later of query start or billing start
            least(qwc.end_time, tqt.usage_end_time)         -- Earlier of query end or billing end
          ),
          0
        ) / tqt.total_query_execution_seconds
      else 0
    end as dbus_consumed
  from query_with_compute qwc
  left join total_query_time_per_billing_period tqt on qwc.workspace_id = tqt.workspace_id
    and coalesce(qwc.cluster_id, qwc.warehouse_id) = tqt.compute_resource_id
    -- Query overlaps with billing period
    and qwc.start_time < tqt.usage_end_time
    and qwc.end_time > tqt.usage_start_time
),

-- Convert allocated DBUs to USD
query_costs as (
  select
    qda.statement_id,
    qda.dbus_consumed,
    lp.pricing.effective_list.default as dbu_unit_price,
    qda.sku_name,
    qda.dbus_consumed * lp.pricing.effective_list.default as estimated_cost_usd
  from query_dbu_allocation qda
  left join {{ databricks_billing_prices_table }} lp on qda.sku_name = lp.sku_name
    and current_date() >= date(lp.price_start_time)
    and (lp.price_end_time is null or current_date() < date(lp.price_end_time))
)

select

  qwc.statement_id as query_id,
  dbt.run_started_at,
  dbt.model_name,
  dbt.relation_name,
  dbt.model_type,
  dbt.model_package,
  dbt.dbt_cloud_job_id,
  dbt.dbt_cloud_run_id,
  dbt.execution_time,
  dbt.status,
  dbt.invocation_id,
  dbt.dbt_version,

  -- Compute information
  qwc.compute_type,
  qwc.cluster_id,
  qwc.warehouse_id,
  qwc.workspace_id,

  -- Cost information
  qc.dbus_consumed,
  qc.dbu_unit_price,
  qc.sku_name,
  qc.estimated_cost_usd,

  -- Query metrics
  qwc.execution_duration_ms,
  qwc.execution_seconds,
  qwc.execution_hours,
  qwc.read_rows,
  qwc.read_bytes,
  qwc.produced_rows,
  qwc.written_bytes,
  qwc.read_bytes / (1024*1024*1024) as gb_read,
  qwc.written_bytes / (1024*1024*1024) as gb_written,

  -- Cost efficiency metrics
  case
    when qwc.produced_rows > 0
    then qc.estimated_cost_usd / qwc.produced_rows
    else null
  end as cost_per_row_produced,

  case
    when qwc.written_bytes > 0
    then qc.estimated_cost_usd / (qwc.written_bytes / 1024.0 / 1024.0)
    else null
  end as cost_per_mb_written

from {{ ref('model_tracking_table') }} as dbt
left join query_with_compute qwc
  on qwc.query_metadata.dbt_cloud_run_id = dbt.dbt_cloud_run_id
  and qwc.query_metadata.node_id = ifnull(dbt.relation_name, qwc.query_metadata.node_id)
  and qwc.query_metadata.node_name = dbt.model_name
  and qwc.query_metadata.invocation_id = dbt.invocation_id
  and qwc.query_text not like '%{{ tracking_table }}%'
  and qwc.start_time >= dbt.run_started_at
  and qwc.start_time <= dbt.insert_timestamp

left join query_costs qc on qwc.statement_id = qc.statement_id

where dbt.dbt_cloud_run_id is not null
  and dbt.dbt_cloud_run_id != 'none'
  and dbt.model_name != 'model_queries'
