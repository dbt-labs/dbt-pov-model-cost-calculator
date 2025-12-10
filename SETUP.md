# Setup Guide

## Permissions Required

### Snowflake
You will need to grant the role used by dbt permissions to query the Snowflake database. See [Snowflake documentation](https://docs.snowflake.com/en/sql-reference/account-usage#enabling-other-roles-to-use-schemas-in-the-snowflake-database) for more information.

### BigQuery
The service account or user running dbt needs:
- `BigQuery Data Viewer` role on the project
- Access to `INFORMATION_SCHEMA.JOBS` in the target project

### Databricks
The user or service principal needs:
- `SELECT` permissions on `system.query.history`
- `SELECT` permissions on `system.billing.usage` and `system.billing.list_prices` (for cost analysis)

## Installation
The following are the required steps for this package to work:
1. **Add the package to your `packages.yml` file**:
   ```yaml
   packages:
     - git: "https://github.com/dbt-labs/dbt-pov-model-cost-calculator.git"
       revision: main # or pin to a specific commit sha
   ```

2. **Add query comment macro in dbt_project.yml**:
   ```yaml
   # Add to your existing dbt_project.yml
   query-comment: "{{ dbt_pov_model_cost_calculator.query_comment(node) }}"
   ```

## Configuration

### Variables

You can customize the plugin behavior using these variables in your `dbt_project.yml`:

```yaml
vars:
  # Schema where the tracking tables will be created
  artifact_schema: "{{ target.schema }}"
  
  # Table name for tracking model executions
  artifact_table: "dbt_model_executions"
  
  # Table name for tracking platform job runs (default: dbt_platform_job_runs)
  artifact_job_runs_table: "dbt_platform_job_runs"
  
  # Batch size for inserting model execution records (default: 500)
  batch_size: 500
  
  # Start date for query monitoring (default: 30 days ago)
  model_monitor_start_date: "2024-01-01"
  
  # Snowflake credit rate for cost calculations (default: $3 per credit)
  snowflake_credit_rate: 3
  
  # BigQuery on-demand pricing per TiB (default: $6.25 for US regions)
  bigquery_on_demand_price_per_tib: 6.25
```

### dbt platform Environment Variables

The plugin automatically detects and uses these dbt Cloud environment variables when available:

- `DBT_CLOUD_RUN_ID`: Unique identifier for the dbt Cloud run
- `DBT_CLOUD_JOB_ID`: Identifier for the dbt Cloud job
- `DBT_CLOUD_PROJECT_ID`: Identifier for the dbt Cloud project
- `DBT_CLOUD_ENVIRONMENT_ID`: Identifier for the dbt Cloud environment
- `DBT_CLOUD_ACCOUNT_ID`: Identifier for the dbt Cloud account
- `DBT_CLOUD_ENVIRONMENT_NAME`: Name of the dbt Cloud environment
- `DBT_CLOUD_ENVIRONMENT_TYPE`: Type of the dbt Cloud environment
- `DBT_CLOUD_INVOCATION_CONTEXT`: Context of the dbt invocation
- `DBT_CLOUD_RUN_REASON_CATEGORY`: Category of the run reason
- `DBT_CLOUD_RUN_REASON`: Reason for the dbt run
- `DBT_CLOUD_GIT_BRANCH`: Git branch used for the run
- `DBT_CLOUD_GIT_SHA`: Git commit SHA used for the run

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

The plugin includes a query comment macro that attaches JSON metadata to all SQL queries executed by dbt.

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

## Execution

The following are the required steps to capture current state costs, SAO costs, and then run the package to calcualte the resulting savings.

The below execution assumes you are directly updating your baseline jobs to utilize SAO, building the package assets to the same schema and database. Updated instructions coming soon for teams testing SAO separate from the environment running their baseline.

1. **Add the query comment macro in your dbt_project.yml along with optional vars of your chosing**:
   ```yaml
   # Add to your existing dbt_project.yml
   query-comment: "{{ dbt_pov_model_cost_calculator.query_comment(node) }}"
   
   vars:
    dbt_pov_model_cost_calculator:
      # Optional: restrict reporting window to recent runs
      model_monitor_start_date: '2025-09-23'
      # Optional: Customize schema where the tracking tables will be created
      artifact_schema: "pov_model_cost_tracking"

   models:
    # Keep the package’s outputs (fct_*/rpt_*) in a clean, separate schema
    dbt_pov_model_cost_calculator:
     +schema: pov_model_cost_calculator
   ```
2. **Run your jobs for a Baseline Window with SAO off**
3. **Turn on SAO for a Comparison Window with SAO jobs**
4. **After you've collected baseline and SAO runs, execute the following:**
    ```bash
    dbt run --select package:dbt_pov_model_cost_calculator
    ```
5. **Reference the [ABOUT.md](https://github.com/dbt-labs/dbt-pov-model-cost-calculator/blob/main/ABOUT.md) to interpret the results**
