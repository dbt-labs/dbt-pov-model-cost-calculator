{% macro _extract_node_config(node) %}
  {% if node.config is mapping %}
      {% set node_config = node.config | tojson  %}
  {% elif node.config.to_dict is defined %}
    {% set node_config = node.config.to_dict() | tojson %}
  {% else %}
    {% set node_config = 'non-serializable node config recieved' %}
  {% endif %}
  {{ return(node_config) }}
{% endmacro %}

{% macro record_dbt_project_models() %}
  {% if execute %}
    {% set tracking_table_fqn = dbt_pov_model_cost_calculator.get_tracking_table_fqn() %}

    {% set node_results = [] %}
    {% for result in results %}
      {% if result.node.resource_type in ['model', 'test', 'snapshot', 'unit_test'] and result.node.package_name != 'dbt_pov_model_cost_calculator' %}
        {% do node_results.append(result) %}
      {% endif %}
    {% endfor %}

    {% set batch_size = var('batch_size', 500) %}
    {% set total_nodes = node_results|length %}
    {% set num_batches = (total_nodes / batch_size)|round(0, 'ceil')|int %}

    {{ log("Processing " ~ total_nodes ~ "model executions in " ~ num_batches ~ " batches of " ~ batch_size, info=true) }}

    {%- for batch_num in range(num_batches) -%}
      {% set start_idx = batch_num * batch_size %}
      {% set end_idx = (start_idx + batch_size, total_nodes)|min %}
      {% set batch_results = node_results[start_idx:end_idx] %}

      {%- if batch_results|length > 0 -%}
        {% set insert_timestamp = modules.datetime.datetime.utcnow().isoformat() %}
        {% set dbt_cloud_run_id = env_var('DBT_CLOUD_RUN_ID', 'none') %}
        {% set dbt_cloud_job_id = env_var('DBT_CLOUD_JOB_ID', 'none') %}
        {% set dbt_cloud_project_id = env_var('DBT_CLOUD_PROJECT_ID', 'none') %}
        {% set dbt_version = dbt_version %}
        {% set run_started_at = run_started_at %}
        {% set batch_insert_sql %}
          insert into {{ tracking_table_fqn }} (
            model_name,
            relation_name,
            model_package,
            model_type,
            status,
            execution_time,
            invocation_id,
            query_id,
            insert_timestamp,
            dbt_cloud_run_id,
            dbt_cloud_job_id,
            dbt_cloud_project_id,
            dbt_version,
            run_started_at,
            node_config
          ) values
          {% for result in batch_results %}
            (
              '{{ result.node.name }}',
              {% if result.relation_name is defined %}'{{ result.relation_name}}'{% else %}null{% endif %},
              '{{ result.node.package_name }}',
              {% if result.node.resource_type == 'model' %}'{{ result.node.config.materialized }}'{% else %}'{{ result.node.resource_type }}'{% endif %},
              '{{ result.status }}',
              {{ result.execution_time }},
              '{{ invocation_id }}',
              {% if result.adapter_response.query_id is defined %}'{{ result.adapter_response.query_id }}'{% else %}'none'{% endif %},
              '{{ insert_timestamp }}',
              {% if dbt_cloud_run_id != 'none' %}'{{ dbt_cloud_run_id }}'{% else %}null{% endif %},
              {% if dbt_cloud_job_id != 'none' %}'{{ dbt_cloud_job_id }}'{% else %}null{% endif %},
              {% if dbt_cloud_project_id != 'none' %}'{{ dbt_cloud_project_id }}'{% else %}null{% endif %},
              '{{ dbt_version }}',
              '{{ run_started_at }}',
              '{{ dbt_pov_model_cost_calculator._extract_node_config(result.node) }}'
            ){% if not loop.last %},{% endif %}
          {% endfor %}
        {% endset %}
        {{ log("Inserting batch sql:" ~ batch_insert_sql, info=true) }}
        {{ log("Inserting batch " ~ (batch_num + 1) ~ "/" ~ num_batches ~ " with " ~ batch_results|length ~ " records", info=true) }}
        {% do run_query(batch_insert_sql) %}
      {%- endif -%}
    {%- endfor -%}

    {{ log("Successfully logged " ~ total_models ~ " model executions in " ~ num_batches ~ " batches", info=true) }}
  {% endif %}
{% endmacro %}
