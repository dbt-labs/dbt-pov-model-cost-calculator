{{
    config(
        materialized='ephemeral'
    )
}}

 {% set base_table_fqn = dbt_pov_model_cost_calculator.get_tracking_table_fqn() %}
  
  {#- Get extra artifact tables from project variable -#}
  {% set extra_tables = var('extra_artifact_tables', []) %}
  
  {#- Start with the base table -#}
  select * from {{ base_table_fqn }}
  
  {#- Union with any extra tables if they exist -#}
  {% if extra_tables and extra_tables | length > 0 %}
    {% for extra_table in extra_tables %}
  union all
  select * from {{ extra_table }}
    {% endfor %}
  {% endif %}