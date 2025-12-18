# About This Package

This document describes the tables, views, and models created by the dbt POV Model Cost Calculator package.

## What Gets Tracked

### Model Executions
For each model execution, the plugin captures data from the [on-run-end results context](https://docs.getdbt.com/reference/dbt-jinja-functions/on-run-end-context#results) object:

- **Model Details**: Name, package, materialization type
- **Execution Status**: Success, error, skipped, or reused
- **dbt Cloud Data**: Run ID, job ID, project ID (when available)
- **Run Context**: Invocation ID, dbt version and query ID

### Platform Job Runs
For each dbt run, the plugin also captures comprehensive platform metadata:

- **dbt Cloud Identifiers**: Run ID, job ID, project ID, environment ID, account ID
- **Environment Context**: Environment name, type, and invocation context
- **Run Context**: Run reason, category, git branch, and commit SHA
- **Execution Metadata**: dbt version, query tag, and invocation arguments
- **Structured Data**: All metadata stored as JSON for flexible querying

## Table Schemas

### Model Executions Table (`dbt_model_executions`)

The primary tracking table includes the following columns:

| Column | Type | Description |
|--------|------|-------------|
| `model_name` | varchar | Name of the dbt model |
| `relation_name` | varchar | Full relation name (database.schema.table) |
| `model_package` | varchar | Package where the model is defined |
| `model_type` | varchar | Materialization type (table, view, etc.) |
| `status` | varchar | Execution status (success, error, skipped, reused) |
| `execution_time` | float | Execution time in seconds |
| `invocation_id` | varchar | Unique dbt run identifier |
| `query_id` | varchar | Unique query identifier (adapter-specific) |
| `insert_timestamp` | timestamp | When this record was inserted |
| `dbt_cloud_run_id` | varchar | dbt Cloud run ID (if applicable) |
| `dbt_cloud_job_id` | varchar | dbt Cloud job ID (if applicable) |
| `dbt_cloud_project_id` | varchar | dbt Cloud project ID (if applicable) |
| `dbt_version` | varchar | dbt version used |
| `run_started_at` | timestamp | When the dbt run started |
| `node_config` | varchar | Model configuration as JSON string |

### Platform Job Runs Table (`dbt_platform_job_runs`)

The platform tracking table includes the following columns:

| Column | Type | Description |
|--------|------|-------------|
| `dbt_cloud_run_id` | varchar | Unique dbt Cloud run identifier |
| `dbt_cloud_job_id` | varchar | dbt Cloud job identifier |
| `dbt_cloud_environment_id` | varchar | dbt Cloud environment identifier |
| `dbt_cloud_project_id` | varchar | dbt Cloud project identifier |
| `dbt_run_context` | json | Comprehensive run metadata including environment details, git info, and execution context |

## Generated Models

The package creates adapter-specific models for cost analysis:

### Fact Tables (Query-Level Analysis)

- **`fct_model_queries`**: Joins model execution tracking data with cloud provider query history and cost information. This model provides detailed cost and performance metrics for each query, including execution time, resource usage, and cost calculations. The model is adapter-specific and automatically uses the appropriate system tables for your data warehouse (BigQuery, Databricks, or Snowflake).

### Report Tables (Aggregated Analysis)

- **`rpt_daily_sao_model_savings`**: Analyzes cost savings from state-aware orchestration by tracking model reuse patterns. This model calculates potential credits and cost savings from avoiding redundant model executions, providing metrics like reuse rates and estimated savings over time.

### State-Aware Orchestration (SAO) Savings Model

The `rpt_daily_sao_model_savings` model provides comprehensive analysis of cost savings from model reuse. This model:

- **Identifies Reused Models**: Tracks models with `status = 'reused'` from the tracking table
- **Calculates Historical Costs**: Aggregates historical cost data for models that were reused
- **Estimates Savings**: Calculates potential credits and cost savings from avoiding redundant executions
- **Provides Metrics**: Includes reuse rates, cost efficiency, and time-series analysis

**Key Metrics Provided:**
- `estimated_credits_saved`: Total Snowflake credits saved from model reuse
- `estimated_cost_saved_usd`: Estimated cost savings in USD
- `reuse_rate_percent`: Percentage of runs where the model was reused vs. executed
- `avg_cost_saved_per_reuse_usd`: Average cost savings per reuse event

### Aggregate Table (Summary Analysis)

- **`agg_savings_summary`**: Summarizes cost savings from state-aware orchestration by tracking model reuse patterns. This model calculates total model reuse and cost savings metrics across your designated summary timeframe.

## How It Works

This package is designed to collect the data necessary for dbt Fusion engine's cost savings analysis:

1. **Pre-Run Setup**: The `on-run-start` hook creates tracking tables if they don't exist
2. **Model Execution Tracking**: The `on-run-end` hook captures model execution details
3. **Platform Metadata Capture**: Records comprehensive dbt Cloud platform metadata for each run
4. **Data Collection**: Iterates through the `results` object to collect execution metadata
5. **Record Insertion**: Inserts records for both model executions and platform job runs
6. **Cost Integration**: Automatically integrates with cloud provider billing data for cost analysis
7. **SAO Analysis**: Generates specialized models for state-aware orchestration savings analysis

The collected data enables analysis of:
- **Execution patterns** that could benefit from Fusion's intelligent scheduling
- **Resource utilization** that could be optimized with state-aware orchestration  
- **Cost trends** to project potential savings from Fusion adoption
- **Model reuse patterns** to calculate actual savings from state-aware orchestration
- **Platform usage patterns** for comprehensive dbt Cloud analytics
