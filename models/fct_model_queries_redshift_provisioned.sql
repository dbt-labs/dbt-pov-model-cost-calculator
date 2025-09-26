{{ config(
    enabled=is_adapter_type('redshift') and not var('is_serverless_redshift', false),
    materialized='view',
    alias='fct_dbt_model_queries'
) }}

{% set tracking_table = var('artifact_table', 'dbt_model_executions') %}
{% set tracking_schema = var('artifact_schema', target.schema) %}
{% set tracking_database = target.database %}
{% set monitor_start_date = var('model_monitor_start_date', (modules.datetime.datetime.now() - modules.datetime.timedelta(days=30)).strftime('%Y-%m-%d')) %}
{% set redshift_provisioned_query_history_table = var('redshift_provisioned_query_history_table', 'SYS_QUERY_HISTORY') %}

{% set redshift_provisioned_node_price_per_hour = var('redshift_provisioned_node_price_per_hour', 0.543) %} -- Default value is for RA3.large
{% set redshift_provisioned_node_count = var('redshift_provisioned_node_count', 1) %}

with queries_in_period as (
  select
    query_id,
    user_id,
    query_text,
    start_time,
    end_time,
    datediff(s, start_time, end_time) as duration_seconds,
    case
      when CAN_JSON_PARSE(REGEXP_SUBSTR(query_text, '\\/\\*\\s*(\\{.*?\\})\\s*\\*\\/', 1, 1, 'ep')) then
        REGEXP_SUBSTR(query_text, '\\/\\*\\s*(\\{.*?\\})\\s*\\*\\/', 1, 1, 'ep')
      else null
    end as query_metadata
  from {{ redshift_provisioned_query_history_table }} queries
  where
    -- Filter out internal system and utility queries (userids 1 and below are system users)
    queries.user_id > 1
    and
    queries.start_time >= '{{ monitor_start_date }}'
    and
    queries.database_name = '{{ tracking_database }}'
    -- Exclude utility commands (COMMIT, BEGIN, SET, etc.) for a cleaner cost estimate
    and
    query_text not ilike 'COMMIT%'
    and
    query_text not ilike 'BEGIN%'
    and
    query_text not ilike 'FETCH%'
    and
    query_text not ilike 'SET%'
    and
    query_text not ilike 'INSERT INTO %'
)
select
  queries.query_id as query_id,
  queries.user_id as user_id,
  -- Display a snippet of the query text
  queries.query_text as query_text,
  queries.start_time as start_time,
  queries.end_time as end_time,
  queries.duration_seconds as duration_seconds,

  -- Calculate the entire cluster's operational cost per second
  (({{ redshift_provisioned_node_price_per_hour }} * {{ redshift_provisioned_node_count }}) / 3600.0) as cluster_cost_per_second,

  -- Estimate query cost: Duration * Cluster Cost Per Second
  (queries.duration_seconds * (({{ redshift_provisioned_node_price_per_hour }} * {{ redshift_provisioned_node_count }}) / 3600.0)) as estimated_cost_usd
from {{ adapter.quote(tracking_database) }}.{{ adapter.quote(tracking_schema) }}.{{ adapter.quote(tracking_table) }} as dbt

inner join queries_in_period queries
on
  json_extract_path_text(queries.query_metadata, 'dbt_cloud_job_id') = dbt.dbt_cloud_job_id
  and
  json_extract_path_text(queries.query_metadata, 'node_name') = dbt.model_name
  and
  queries.start_time >= dbt.run_started_at
  and
  queries.start_time <= dbt.insert_timestamp

where
  dbt.dbt_cloud_job_id is not null
  and
  dbt.dbt_cloud_job_id != 'none'
  and
  dbt.model_name != 'model_queries'

order by
  estimated_cost_usd desc,
  queries.duration_seconds desc
