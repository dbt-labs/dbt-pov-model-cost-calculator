# dbt Cost Savings POV

A specialized dbt package designed to help dbt Labs calculate potential cost savings customers may realize from switching to dbt's fusion state-aware orchestration. 

 This package tracks model execution patterns and costs to analyze the efficiency gains possible with fusion's intelligent scheduling and resource optimization.

> **Important**: This package is designed specifically for dbt Labs' internal proof-of-value of fusion cost savings potential. While the community is free to use it, dbt Labs support is limited to this specific purpose. For general model cost tracking and monitoring, we recommend using community or vendor-supported packages (see [Alternative Solutions](#alternative-solutions) below).

## Purpose

This package enables analysis of:
- **Model execution patterns** and their associated costs
- **Resource utilization** across different scheduling approaches  
- **Potential savings** from fusion's state-aware orchestration
- **Historical cost trends** to project fusion benefits

## Features

- **Automatic Model Tracking**: Captures execution details for every model in your dbt project
- **Cost Analysis**: Integrates with cloud provider billing data (BigQuery, Databricks, Snowflake)
- **dbt Cloud Integration**: Automatically captures dbt Cloud run, job, and project IDs when available
- **Incremental Design**: Builds up historical data over time without duplicating records
- **Fusion Analysis Ready**: Structured data optimized for fusion cost savings calculations

## What Gets Tracked

For each model execution, the plugin captures:

- **Model Details**: Name, package, materialization type
- **Execution Status**: Success, error, or skipped
- **Performance Metrics**: Execution time
- **Environment Info**: dbt version
- **Timestamps**: Record insertion time and run start time
- **dbt Cloud Data**: Run ID, job ID, project ID (when available)
- **Run Context**: Invocation ID and query ID (adapter-specific)
- **Query Comments**: Comprehensive JSON metadata attached to all SQL queries

## Installation

1. Update packages.yml

2. **Configure your dbt_project.yml**:
   ```yaml
   # Add to your existing dbt_project.yml
   on-run-end:
     - "{{ record_dbt_project_models() }}"
   
  # Optional: Add comprehensive query comments
  query-comment: "{{ dbt_model_build_reporter.query_comment(node) }}"
   
   vars:
     artifact_schema: "{{ target.schema }}"
     artifact_table: "dbt_model_executions"
   ```

3. **Run your first dbt command**:
   ```bash
   dbt run
   ```

## Alternative Solutions

For general model cost tracking and data observability beyond fusion cost analysis, we recommend these community and vendor-supported packages:

### Community Packages

- **[Elementary dbt-data-reliability](https://github.com/elementary-data/dbt-data-reliability)**: Comprehensive data observability package with anomaly detection, schema monitoring, and cost tracking capabilities
- **[select.dev packages](https://select.dev/)**: Professional data observability and cost monitoring solutions
- **[dbt-artifacts](https://github.com/brooklyn-data/dbt_artifacts)

### Why Use Alternatives?

While this package is freely available, it's specifically designed for dbt Labs' fusion cost analysis. For broader data observability needs, the packages above offer:

- **Dedicated support** from their respective teams
- **Regular updates** and feature development
- **Comprehensive documentation** and community resources
- **Production-ready** monitoring and alerting capabilities
- **Integration** with popular data observability platforms

## Configuration

### Variables

You can customize the plugin behavior using these variables in your `dbt_project.yml`:

```yaml
vars:
  # Schema where the tracking table will be created
  artifact_schema: "{{ target.schema }}"
  
  # Table name for tracking model executions
  artifact_table: "dbt_model_executions"
  
  # Batch size for inserting model execution records (default: 500)
  batch_size: 500
  
  # Start date for query monitoring (default: 30 days ago)
  model_monitor_start_date: "2024-01-01"
```

### dbt Cloud Environment Variables

The plugin automatically detects and uses these dbt Cloud environment variables when available:

- `DBT_CLOUD_RUN_ID`: Unique identifier for the dbt Cloud run
- `DBT_CLOUD_JOB_ID`: Identifier for the dbt Cloud job
- `DBT_CLOUD_PROJECT_ID`: Identifier for the dbt Cloud project

### Batch Size Configuration

The `batch_size` variable controls how many model execution records are inserted in each batch. This can be adjusted based on your needs:

- **Smaller batches (100-250)**: Better for environments with memory constraints or slower networks
- **Default (500)**: Good balance of performance and memory usage for most use cases
- **Larger batches (1000+)**: Better performance for large dbt projects with many models

**Example configurations:**
```yaml
# For large projects with 1000+ models
batch_size: 1000

# For memory-constrained environments
batch_size: 100

# For maximum performance (use with caution)
batch_size: 2000
```

### Query Monitoring Time Range

The `model_monitor_start_date` variable controls how far back to look for query history data. This helps manage performance and data volume:

- **Default**: 30 days ago (automatically calculated)
- **Custom Date**: Set to a specific date like `"2024-01-01"`
- **Performance**: Shorter time ranges improve query performance
- **Data Volume**: Longer time ranges provide more historical context

**Example configurations:**
```yaml
# Monitor queries from the last 7 days
model_monitor_start_date: "{{ (modules.datetime.datetime.now() - modules.datetime.timedelta(days=7)).strftime('%Y-%m-%d') }}"

# Monitor queries from a specific date
model_monitor_start_date: "2024-01-01"

# Monitor queries from the last 90 days
model_monitor_start_date: "{{ (modules.datetime.datetime.now() - modules.datetime.timedelta(days=90)).strftime('%Y-%m-%d') }}"
```

### System Table Overrides

The plugin allows you to override the default system tables used for query monitoring. This is useful for:

- **Custom Environments**: Using different system tables in dev/staging/prod
- **Alternative Data Sources**: Pointing to custom tables with similar schemas
- **Testing**: Using mock or test system tables

**Available Variables:**

```yaml
vars:
  # BigQuery system table overrides
  bigquery_jobs_table: "my_project.region-us.INFORMATION_SCHEMA.JOBS"
  
  # Databricks system table overrides
  databricks_query_history_table: "system.query.history"
  databricks_billing_usage_table: "system.billing.usage"
  databricks_billing_prices_table: "system.billing.list_prices"
  
  # Snowflake system table overrides
  snowflake_query_history_table: "snowflake.account_usage.query_history"
  snowflake_query_attribution_table: "snowflake.account_usage.query_attribution_history"
```

**Usage Examples:**

```bash
# Override BigQuery jobs table
dbt run --vars 'bigquery_jobs_table: "my_project.region-eu.INFORMATION_SCHEMA.JOBS"'

# Override multiple Databricks tables
dbt run --vars 'databricks_query_history_table: "custom.query_history" databricks_billing_usage_table: "custom.billing_usage"'

# Use environment variables for different environments
dbt run --vars 'snowflake_query_history_table: "{{ env_var("SNOWFLAKE_QUERY_HISTORY_TABLE", "snowflake.account_usage.query_history") }}"'
```

**Environment-Specific Configuration:**

```yaml
# dbt_project.yml
vars:
  # Use environment variables with fallbacks
  bigquery_jobs_table: "{{ env_var('BIGQUERY_JOBS_TABLE', target.project ~ '.region-' ~ (target.compute_region | default('us')) ~ '.INFORMATION_SCHEMA.JOBS') }}"
  databricks_query_history_table: "{{ env_var('DATABRICKS_QUERY_HISTORY_TABLE', 'system.query.history') }}"
  snowflake_query_history_table: "{{ env_var('SNOWFLAKE_QUERY_HISTORY_TABLE', 'snowflake.account_usage.query_history') }}"
```

### Query Comments

The plugin includes a comprehensive query comment system that attaches JSON metadata to all SQL queries executed by dbt. This follows [dbt's best practices for query comments](https://docs.getdbt.com/reference/project-configs/query-comment#advanced-use-a-macro-to-generate-a-comment).

**Query Comment Features:**
- **Model Identification**: Includes node ID, name, package, and file path
- **Execution Context**: dbt version, profile, target, and invocation ID
- **dbt Cloud Integration**: Run ID, job ID, and project ID when available
- **Database Relations**: Target database, schema, and identifier information

**Example Query Comment:**
```json
{
  "invocation_id": "abc123",
  "dbt_cloud_job_id": "12345",
  "node_id": "model.my_project.my_model",
  "node_name": "my_model",
  "package_name": "my_project",
  "relation": {
    "database": "my_database",
    "schema": "my_schema", 
    "identifier": "my_model"
  }
}
```

## Table Schema

The tracking table includes the following columns:

| Column | Type | Description |
|--------|------|-------------|
| `model_name` | varchar | Name of the dbt model |
| `model_package` | varchar | Package where the model is defined |
| `model_type` | varchar | Materialization type (table, view, etc.) |
| `status` | varchar | Execution status (success, error, skipped) |
| `execution_time` | float | Execution time in seconds |
| `invocation_id` | varchar | Unique dbt run identifier |
| `query_id` | varchar | Unique query identifier (adapter-specific) |
| `insert_timestamp` | timestamp | When this record was inserted |
| `dbt_cloud_run_id` | varchar | dbt Cloud run ID (if applicable) |
| `dbt_cloud_job_id` | varchar | dbt Cloud job ID (if applicable) |
| `dbt_cloud_project_id` | varchar | dbt Cloud project ID (if applicable) |
| `dbt_version` | varchar | dbt version used |
| `run_started_at` | timestamp | When the dbt run started |

## Usage Examples

### Fusion Cost Analysis

The primary use case for this package is analyzing potential cost savings from dbt's fusion state-aware orchestration:

```sql
-- Analyze model execution patterns for fusion optimization
select 
  model_name,
  avg(execution_time) as avg_execution_time,
  count(*) as execution_count,
  sum(case when status = 'success' then 1 else 0 end) as success_count
from {{ var('artifact_table', 'dbt_model_executions') }}
where run_started_at >= current_date - interval '30 days'
group by model_name
order by avg_execution_time desc;
```

### Resource Utilization Analysis

```sql
-- Identify models with high resource usage for fusion optimization
select 
  model_name,
  model_type,
  avg(execution_time) as avg_execution_time,
  count(*) as total_runs,
  sum(case when status = 'error' then 1 else 0 end) as error_count
from {{ var('artifact_table', 'dbt_model_executions') }}
where status in ('success', 'error')
group by model_name, model_type
having count(*) > 10  -- Only models with significant execution history
order by avg_execution_time desc;
```

### Execution Pattern Analysis

```sql
-- Analyze execution patterns to identify fusion optimization opportunities
select 
  date_trunc('day', run_started_at) as execution_date,
  count(*) as total_executions,
  count(distinct model_name) as unique_models,
  avg(execution_time) as avg_execution_time
from {{ var('artifact_table', 'dbt_model_executions') }}
where run_started_at >= current_date - interval '30 days'
group by date_trunc('day', run_started_at)
order by execution_date desc;
```

### Query History and Cost Analysis

The plugin automatically creates adapter-specific models for query history analysis:

- **BigQuery**: `model_queries_bigquery` - Includes bytes billed, slot usage, and cost estimates
- **Databricks**: `model_queries_databricks` - Includes scan size, execution time, and cost estimates  
- **Snowflake**: `model_queries_snowflake` - Includes credits used, warehouse info, and attribution data

**Example - BigQuery Cost Analysis:**
```sql
select 
  model_name,
  sum(gb_billed) as total_gb_billed,
  sum(estimated_cost_usd) as total_cost_usd,
  count(*) as query_count
from model_queries_bigquery
group by model_name
order by total_cost_usd desc;
```

**Example - Snowflake Credit Usage:**
```sql
select 
  model_name,
  sum(credits_attributed_compute) as total_compute_credits,
  sum(credits_used_query_acceleration) as total_acceleration_credits,
  warehouse_name
from model_queries_snowflake
group by model_name, warehouse_name
order by total_compute_credits desc;
```

## How It Works

This package is designed to collect the data necessary for fusion cost savings analysis:

1. **Hook Execution**: The `on-run-end` hook runs after all models have been executed
2. **Table Creation**: Creates the tracking table if it doesn't exist
3. **Data Collection**: Iterates through the `results` object to collect execution metadata
4. **Record Insertion**: Inserts a record for each model execution with comprehensive details
5. **Cost Integration**: Automatically integrates with cloud provider billing data for cost analysis
6. **Fusion Analysis**: Provides structured data optimized for calculating potential fusion savings

The collected data enables analysis of:
- **Execution patterns** that could benefit from fusion's intelligent scheduling
- **Resource utilization** that could be optimized with state-aware orchestration  
- **Cost trends** to project potential savings from fusion adoption

## Troubleshooting

### Common Issues

1. **Table Creation Fails**: Ensure your database user has CREATE TABLE permissions
2. **Missing dbt Cloud Variables**: Environment variables are only available in dbt Cloud, not in local development
3. **Permission Errors**: Verify your database user has INSERT permissions on the target schema

### Debugging

Enable debug logging to see detailed information about the plugin's operation:

```bash
dbt run --log-level debug
```

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

**Limited Support Scope**: This package is designed specifically for dbt Labs' fusion cost analysis. Support is limited to issues related to this specific purpose.

For general questions and community support:
- Join the [dbt Community Slack](http://community.getdbt.com/)
- Read more on the [dbt Community Discourse](https://discourse.getdbt.com)

For fusion cost analysis issues:
- Open an issue on GitHub for bugs or feature requests related to fusion cost calculations

For general model cost tracking and data observability:
- Consider using [Elementary](https://github.com/elementary-data/dbt-data-reliability) or [select.dev](https://select.dev/) packages with dedicated support teams
