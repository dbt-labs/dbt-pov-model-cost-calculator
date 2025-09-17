{% macro query_comment(node) %}
  {# Generate a comprehensive query comment following dbt best practices #}
  {%- set comment_dict = {} -%}
  {%- if invocation_id is defined -%}
    {%- do comment_dict.update(
        invocation_id=invocation_id
    ) -%}
  {%- endif -%}
  
  {# Add dbt Cloud identifiers if available #}
  {%- set dbt_cloud_job_id = env_var('DBT_CLOUD_JOB_ID', 'fusion') -%}
  
  {%- if dbt_cloud_job_id -%}
    {%- do comment_dict.update(dbt_cloud_job_id=dbt_cloud_job_id) -%}
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

{% macro generate_query_comment(model_name=none, model_package=none, invocation_id=none) %}
  {# Legacy macro for backward compatibility - generates a simple string format #}
  {%- set dbt_cloud_job_id = env_var('DBT_CLOUD_JOB_ID', 'fusion') -%}
  
  {%- set comment_parts = [] -%}
  
  {# Add model identifier #}
  {%- if model_name -%}
    {%- if model_package -%}
      {%- do comment_parts.append('model=' ~ model_package ~ '.' ~ model_name) -%}
    {%- else -%}
      {%- do comment_parts.append('model=' ~ model_name) -%}
    {%- endif -%}
  {%- endif -%}
  
  {# Add invocation ID #}
  {%- if invocation_id -%}
    {%- do comment_parts.append('invocation_id=' ~ invocation_id) -%}
  {%- endif -%}
  
  {# Add dbt Cloud identifiers #}
  {%- if dbt_cloud_job_id -%}
    {%- do comment_parts.append('dbt_cloud_job_id=' ~ dbt_cloud_job_id) -%}
  {%- endif -%}
  
  {# Join all parts with semicolon separator #}
  {%- set query_comment = comment_parts | join('; ') -%}
  
  {{ return(query_comment) }}
{% endmacro %}
