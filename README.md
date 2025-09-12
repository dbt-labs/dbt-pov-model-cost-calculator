# dbt Artifact Now

A dbt plugin that maintains an incrementally built table in your target database containing a record for every model execution. This plugin leverages the `on-run-end` hook to automatically track model executions with comprehensive metadata.

## Features

- **Automatic Model Tracking**: Captures execution details for every model in your dbt project
- **Comprehensive Metadata**: Includes execution status, timing, row counts, and environment details
- **dbt Cloud Integration**: Automatically captures dbt Cloud run, job, and project IDs when available
- **Incremental Design**: Builds up historical data over time without duplicating records
- **Flexible Configuration**: Customizable table name and schema location

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

1. **Clone or download this repository**
2. **Copy the plugin files to your dbt project**:
   ```bash
   # Copy the macros directory
   cp -r macros/ /path/to/your/dbt/project/
   
   # Copy the dbt_project.yml configuration (merge with your existing config)
   ```

3. **Configure your dbt_project.yml**:
   ```yaml
   # Add to your existing dbt_project.yml
   on-run-end:
     - "{{ log_model_executions() }}"
   
   # Optional: Add comprehensive query comments
   query-comment: "{{ query_comment(node) }}"
   
   vars:
     artifact_schema: "{{ target.schema }}"
     artifact_table: "dbt_model_executions"
   ```

4. **Run your first dbt command**:
   ```bash
   dbt run
   ```

## Configuration

### Variables

You can customize the plugin behavior using these variables in your `dbt_project.yml`:

```yaml
vars:
  # Schema where the tracking table will be created
  artifact_schema: "{{ target.schema }}"
  
  # Table name for tracking model executions
  artifact_table: "dbt_model_executions"
```

### dbt Cloud Environment Variables

The plugin automatically detects and uses these dbt Cloud environment variables when available:

- `DBT_CLOUD_RUN_ID`: Unique identifier for the dbt Cloud run
- `DBT_CLOUD_JOB_ID`: Identifier for the dbt Cloud job
- `DBT_CLOUD_PROJECT_ID`: Identifier for the dbt Cloud project

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
  "app": "dbt_artifact_now",
  "dbt_version": "1.6.0",
  "profile_name": "my_project",
  "target_name": "dev",
  "invocation_id": "abc123",
  "dbt_cloud_job_id": "12345",
  "dbt_cloud_run_id": "67890",
  "node_id": "model.my_project.my_model",
  "node_name": "my_model",
  "resource_type": "model",
  "package_name": "my_project",
  "file": "models/my_model.sql",
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

### Query Recent Model Executions

```sql
select 
  model_name,
  status,
  execution_time,
  model_execution_timestamp
from {{ var('artifact_table', 'dbt_model_executions') }}
order by model_execution_timestamp desc
limit 10;
```

### Find Failed Models

```sql
select 
  model_name,
  status,
  model_execution_timestamp,
  dbt_cloud_run_id
from {{ var('artifact_table', 'dbt_model_executions') }}
where status = 'error'
order by model_execution_timestamp desc;
```

### Performance Analysis

```sql
select 
  model_name,
  avg(execution_time) as avg_execution_time,
  max(execution_time) as max_execution_time,
  count(*) as execution_count
from {{ var('artifact_table', 'dbt_model_executions') }}
where status = 'success'
group by model_name
order by avg_execution_time desc;
```

## How It Works

1. **Hook Execution**: The `on-run-end` hook runs after all models have been executed
2. **Table Creation**: Creates the tracking table if it doesn't exist
3. **Data Collection**: Iterates through the `results` object to collect execution metadata
4. **Record Insertion**: Inserts a record for each model execution with comprehensive details

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

- Join the [dbt Community Slack](http://community.getdbt.com/)
- Read more on the [dbt Community Discourse](https://discourse.getdbt.com)
- Open an issue on GitHub for bugs or feature requests
