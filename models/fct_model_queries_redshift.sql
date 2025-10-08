{{ config(
    enabled=is_adapter_type('redshift'),
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

{% set is_serverless_redshift = var('is_serverless_redshift', false) | as_bool %}
{% set redshift_serverless_query_history_table = var('redshift_serverless_query_history_table', 'SYS_QUERY_HISTORY') %}
{% set redshift_serverless_usage_table = var('redshift_serverless_usage_table', 'SYS_SERVERLESS_USAGE') %}

-- Redshift Serverless is billed based on RPU hours consumed. RPU's are
-- based off of all the concurrently running queries on a per minute basis.
--
-- Pricing: $0.36 per RPU hour consumed in US regions
-- Reference: https://aws.amazon.com/redshift/pricing/#Amazon_Redshift_Serverless
-- Note: Pricing varies by region - update the pricing constant below for different regions
{% set redshift_serverless_usage_price_per_hour = var('redshift_serverless_usage_price_per_hour', 0.36) %}

{% if is_serverless_redshift == True %}
  {{ log("Using serverless Redshift model", info=True) }}

  with queries_in_period as (
    select
      query_id,
      query_text,
      elapsed_time,
      execution_time,
      queue_time,
      start_time,
      end_time,
      CASE
        WHEN CAN_JSON_PARSE(REGEXP_SUBSTR(query_text, '\\/\\*\\s*(\\{.*?\\})\\s*\\*\\/', 1, 1, 'ep')) THEN
          REGEXP_SUBSTR(query_text, '\\/\\*\\s*(\\{.*?\\})\\s*\\*\\/', 1, 1, 'ep')
        ELSE null
      END AS query_metadata,
      json_extract_path_text(query_metadata, 'node_id') as extracted_node_id
    from {{ redshift_serverless_query_history_table }} as queries
    where
      queries.start_time >= '{{ monitor_start_date }}'
      and
      queries.database_name = '{{ tracking_database }}'
  ),

  rpus_per_query as (
    select
      queries.query_id,
      sum(serverless_usage.charged_seconds) as total_charged_seconds
    from {{ redshift_serverless_usage_table }} as serverless_usage
    join queries_in_period as queries
    on
      queries.start_time >= serverless_usage.start_time
      and
      queries.end_time <= serverless_usage.end_time
    group by queries.query_id
  ),

  queries_with_metadata as (
    select
      queries.query_id,
      queries.query_text,
      queries.elapsed_time,
      queries.execution_time,
      queries.queue_time,
      start_time,
      query_metadata,
      rpus.total_charged_seconds,
      queries.extracted_node_id
    from queries_in_period as queries
    join rpus_per_query as rpus
    on queries.query_id = rpus.query_id
  )

  select
    queries.query_id as query_id,
    queries.query_text as query_text,
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

    -- Cost information
    (queries.total_charged_seconds / 3600) * {{ redshift_serverless_usage_price_per_hour }} as estimated_cost_usd,

    -- Query metrics
    queries.elapsed_time as elapsed_time,
    queries.execution_time as query_execution_time,
    queries.queue_time as queue_time

  from {{ adapter.quote(tracking_database) }}.{{ adapter.quote(tracking_schema) }}.{{ adapter.quote(tracking_table) }} as dbt
  inner join queries_with_metadata as queries
    on
      json_extract_path_text(queries.query_metadata, 'dbt_cloud_job_id') = dbt.dbt_cloud_job_id
      and
      json_extract_path_text(queries.query_metadata, 'node_name') = dbt.model_name
      and
      queries.extracted_node_id = coalesce(dbt.relation_name, queries.extracted_node_id)
      and
      queries.start_time >= dbt.run_started_at
      and
      queries.start_time <= dbt.insert_timestamp

  where dbt.dbt_cloud_job_id is not null
    and dbt.dbt_cloud_job_id != 'none'
    and dbt.model_name != 'model_queries'

  order by
    estimated_cost_usd DESC,
    elapsed_time DESC
{% else %}
  {{ log("Using provisioned Redshift model", info=True) }}

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
      end as query_metadata,
      json_extract_path_text(query_metadata, 'node_id') as extracted_node_id
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
    queries.extracted_node_id = coalesce(dbt.relation_name, queries.extracted_node_id)
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
{% endif %}