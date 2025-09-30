{% macro query_comment(node) %}
  {# Generate a comprehensive query comment following dbt best practices #}
  {%- set comment_dict = {} -%}
  {%- if invocation_id is defined -%}
    {%- do comment_dict.update(
        invocation_id=invocation_id
    ) -%}
  {%- endif -%}

  {# Add dbt Cloud identifiers if available #}
  {%- set dbt_cloud_job_id = env_var('DBT_CLOUD_JOB_ID', invocation_id) -%}
  {%- set dbt_cloud_run_id = env_var('DBT_CLOUD_RUN_ID', modules.datetime.datetime.utcnow().timestamp()) -%}

  {%- if dbt_cloud_job_id -%}
    {%- do comment_dict.update(dbt_cloud_job_id=dbt_cloud_job_id) -%}
    {%- do comment_dict.update(dbt_cloud_run_id=dbt_cloud_run_id) -%}
  {%- endif -%}

  {# Add node information if available #}
  {%- if node is not none -%}
    {%- do comment_dict.update(
      node_id=node.unique_id,
      node_name=node.name,
      package_name=node.package_name,
      relation={
          "database": node.database,
          "schema": node.schema,
          "identifier": node.identifier
      }
    ) -%}
  {%- else -%}
    {%- do comment_dict.update(node_id='internal') -%}
  {%- endif -%}

  {{ return(tojson(comment_dict)) }}
{% endmacro %}
