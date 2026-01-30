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
Basic installation only requires the following:
**Add the package to your `packages.yml` file**:
   ```yaml
   packages:
     - git: "https://github.com/dbt-labs/dbt-pov-model-cost-calculator.git"
       revision: main # or pin to a specific commit sha
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
  
  # Cost savings calculator enablement control (optional)
  # Controls both model enablement and artifact tracking
  # Default: true (enabled for all targets)
  # 
  # Examples:
  #   Enable only in specific targets:
  #   enable_cost_savings_calculator: "{{ target.name in ['dev', 'prod'] }}"
  #   
  #   Enable based on environment variable:
  #   enable_cost_savings_calculator: "{{ env_var('ENABLE_COST_CALCULATOR', 'true') | as_bool }}"
  enable_cost_savings_calculator: true
  
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

### Model Enablement and Artifact Tracking Control

The package provides flexible control over which models are enabled and whether artifact tracking is active.

#### Cost Savings Calculator Enablement Control

The `enable_cost_savings_calculator` variable controls all cost calculator functionality:
1. **Model enablement** - Whether cost calculator models are created/updated
2. **Artifact tracking** - Whether tracking tables are created and populated
3. **Run data collection** - Whether run metadata is recorded

This boolean variable gives you complete flexibility to implement your own enablement logic.

#### Using `is_enabled` Macro

The `is_enabled` macro combines adapter type checking with cost calculator enablement control:

```sql
{{ config(
    enabled=dbt_pov_model_cost_calculator.is_enabled('snowflake')
) }}
```

**Parameters:**
- `adapter_type` (required): The database adapter type (e.g., 'snowflake', 'bigquery', 'databricks')

**Behavior:**
1. Model is disabled if adapter type doesn't match `target.type`
2. Model is disabled if `enable_cost_savings_calculator` variable is false
3. Model is enabled if both checks pass

**Usage Examples:**

```sql
-- Enable on Snowflake (respects enable_cost_savings_calculator setting)
{{ config(enabled=dbt_pov_model_cost_calculator.is_enabled('snowflake')) }}

-- Enable on BigQuery (respects enable_cost_savings_calculator setting)
{{ config(enabled=dbt_pov_model_cost_calculator.is_enabled('bigquery')) }}

-- Enable on Databricks (respects enable_cost_savings_calculator setting)
{{ config(enabled=dbt_pov_model_cost_calculator.is_enabled('databricks')) }}
```

**Calculator-Level Enablement Control:**

Control all cost calculator functionality with the `enable_cost_savings_calculator` variable in your `dbt_project.yml`:

```yaml
vars:
  # Enable only in specific targets
  enable_cost_savings_calculator: "{{ target.name in ['dev', 'prod'] }}"
```

```yaml
vars:
  # Enable based on environment variable
  enable_cost_savings_calculator: "{{ env_var('ENABLE_COST_CALCULATOR', 'true') | as_bool }}"
```

```yaml
vars:
  # Custom logic combining multiple conditions
  enable_cost_savings_calculator: "{{ target.name == 'prod' and env_var('ENABLE_TRACKING', 'false') | as_bool }}"
```

```yaml
vars:
  # Always enabled (default behavior)
  enable_cost_savings_calculator: true
```

```yaml
vars:
  # Always disabled
  enable_cost_savings_calculator: false
```

**What Happens When Calculator Is Disabled:**

When `enable_cost_savings_calculator` is set to `false`:
- Cost calculator models will not be created/updated
- Artifact tracking tables will not be created
- Model execution data will not be recorded
- Run metadata will not be captured
- Log messages will indicate tracking is skipped

Example log output:
```
Skipping artifact tracking table creation - enable_cost_savings_calculator is set to false
Skipping model execution tracking - enable_cost_savings_calculator is set to false
Skipping run data tracking - enable_cost_savings_calculator is set to false
```

**Common Use Cases:**

1. **Enable only in production:**
```yaml
vars:
  enable_cost_savings_calculator: "{{ target.name == 'prod' }}"
```

2. **Disable for local development:**
```yaml
vars:
  enable_cost_savings_calculator: "{{ target.name != 'local' }}"
```

3. **Enable in multiple environments:**
```yaml
vars:
  enable_cost_savings_calculator: "{{ target.name in ['dev', 'staging', 'prod'] }}"
```

4. **Control via environment variable:**
```yaml
vars:
  enable_cost_savings_calculator: "{{ env_var('ENABLE_COST_TRACKING', 'false') | as_bool }}"
```

Then run:
```bash
export ENABLE_COST_TRACKING=true
dbt run
```

5. **Disable during CI/CD:**
```yaml
vars:
  enable_cost_savings_calculator: "{{ env_var('CI', 'false') != 'true' }}"
```

This approach gives you complete flexibility to implement your own enablement logic based on:
- Target names
- Environment variables
- Custom business logic
- Any other Jinja expression that evaluates to a boolean

#### Legacy `is_adapter_type` Macro

For backward compatibility, the `is_adapter_type` macro is still available:

```sql
{{ config(enabled=dbt_pov_model_cost_calculator.is_adapter_type('snowflake')) }}
```

This only checks adapter type without cost calculator enablement control. **Recommend migrating to `is_enabled` for enhanced control and consistency with artifact tracking behavior.**

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

The following are the required steps to capture current state costs, SAO costs, and then run the package to calculate the resulting savings.

The below execution assumes you are directly updating your baseline jobs to utilize SAO, building the package assets to the same schema and database.

The Baseline Window mentioned below may vary based on your orchestration schedule. If you have mostly daily jobs or very impactful weekly jobs, a week of tracking may be best. If you have mostly hourly jobs, a few days of tracking may be sufficient. Whatever you choose, just be sure you are comofrtable extrapolating out your tracking window savings to estimate across a year.

1. **Add the query comment macro in your dbt_project.yml along with optional vars of your chosing**\
   NOTE: You must add the below query comment into your dbt_project.yml in order for the package to successfully connect to warehouse metadata. If you already have a query comment called out in your root dbt_project.yml, you will need to append the package query-comment to it. For example:
   ```yaml
   # Add the package query comment to your existing dbt_project.yml fresh (without the existing_comment and dash) or appended to your existing query comment like below
   query-comment: "existing_comment - {{ dbt_pov_model_cost_calculator.query_comment(node) }}"
   
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
2. **Run your jobs for a Baseline Window with SAO off**\
   Make sure to confirm you see records being stored in your dbt_model_executions table (or whatever custom artifact_table name you set). Once you have records in this table, try running the fct_model_queries_warehouse model to confirm the package is connecting to warehouse metadata as expected.
3. **Turn on SAO for a Comparison Window with SAO jobs**
4. **After you've collected baseline and SAO runs, execute the following:**\
   **Snowflake and Databricks Users:**\
   Use the below command to create your agg_sao_savings_summary model. The summary date variables give you flexibility to calculate your aggregate savings summary across a defined timeframe. If no variables are passed in, the agg_sao_savings_summary_warehouse model will calculate over the last full 7 days.
    ```bash
    dbt run --select package:dbt_pov_model_cost_calculator --vars '{"summary_start_date": "2025-12-04", "summary_end_date": "2025-12-11"}'
    ```
   **BigQuery Users:**\
   Use the below command to create your rpt_daily_sao_model_savings model.
    ```bash
    dbt run --select package:dbt_pov_model_cost_calculator
    ```
5. **Reference the [ABOUT.md](https://github.com/dbt-labs/dbt-pov-model-cost-calculator/blob/main/ABOUT.md) to interpret the results**
