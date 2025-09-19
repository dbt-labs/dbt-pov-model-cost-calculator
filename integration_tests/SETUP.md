# Integration Test Setup Guide

This guide explains how to set up the integration tests for the `dbt_model_build_reporter` package.

## GitHub Secrets Configuration

To run the integration tests via GitHub Actions, you need to configure the following secrets in your repository:

### Setting up GitHub Secrets

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** for each required secret

### Required Secrets

#### Snowflake Secrets
```
SNOWFLAKE_ACCOUNT     # Your Snowflake account identifier
SNOWFLAKE_USER        # Username for Snowflake connection
SNOWFLAKE_PASSWORD    # Password for Snowflake connection
SNOWFLAKE_ROLE        # Role to use (e.g., ACCOUNTADMIN, SYSADMIN)
SNOWFLAKE_DATABASE    # Database name for testing
SNOWFLAKE_WAREHOUSE   # Warehouse name for testing
SNOWFLAKE_SCHEMA      # Schema name for testing
```

#### Databricks Secrets
```
DATABRICKS_HOST       # Your Databricks workspace URL
DATABRICKS_HTTP_PATH  # HTTP path for SQL warehouse
DATABRICKS_TOKEN      # Personal access token
DATABRICKS_SCHEMA     # Schema name for testing
```

#### BigQuery Secrets
```
BIGQUERY_PROJECT      # Your GCP project ID
BIGQUERY_DATASET      # Dataset name for testing
BIGQUERY_KEYFILE      # Service account key file (JSON content)
BIGQUERY_LOCATION     # Location/region (optional, defaults to 'US')
```

## Local Development Setup

### Prerequisites

1. **Python 3.11+** installed
2. **dbt Core** and adapter packages:
   ```bash
   pip install dbt-core dbt-snowflake dbt-databricks dbt-bigquery
   ```

### Environment Variables

#### Quick Setup

Use the provided setup script to create your `.env` file:

```bash
cd integration_tests
./setup_env.sh
```

This will create a `.env` file from the template and guide you through the setup process.

#### Manual Setup

Alternatively, you can manually create a `.env` file:

1. Copy the template:
   ```bash
   cp env_template.txt .env
   ```

2. Edit the `.env` file and replace all `your_*` placeholders with your actual values.

#### Environment Variables Reference

The `.env` file should contain:

```bash
# Snowflake
SNOWFLAKE_ACCOUNT=your_snowflake_account
SNOWFLAKE_USER=your_snowflake_username
DBT_ENV_SECRET_SNOWFLAKE_PASSWORD=your_snowflake_password
SNOWFLAKE_ROLE=your_snowflake_role
SNOWFLAKE_DATABASE=dbt_model_build_reporter_test
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
SNOWFLAKE_SCHEMA=test_schema

# Databricks
DATABRICKS_HOST=https://your-workspace.cloud.databricks.com
DATABRICKS_HTTP_PATH=/sql/1.0/warehouses/your_warehouse_id
DBT_ENV_SECRET_DATABRICKS_TOKEN=your_databricks_token
DATABRICKS_SCHEMA=test_schema

# BigQuery
BIGQUERY_PROJECT=your_gcp_project_id
BIGQUERY_DATASET=dbt_model_build_reporter_test
DBT_ENV_SECRET_BIGQUERY_KEYFILE={"type":"service_account",...}
BIGQUERY_LOCATION=US
```

**Important Notes:**
- Use `DBT_ENV_SECRET_` prefix for sensitive information (passwords, tokens, keys)
- For BigQuery, you can put the full JSON keyfile content or a file path
- Never commit the `.env` file to version control

### Running Tests Locally

1. **Navigate to integration tests directory:**
   ```bash
   cd integration_tests
   ```

2. **Run tests for a specific adapter:**
   ```bash
   ./run_tests.sh snowflake full
   ./run_tests.sh databricks full
   ./run_tests.sh bigquery full
   ```

3. **Run tests for all adapters:**
   ```bash
   ./run_tests.sh all full
   ```

4. **Run specific commands:**
   ```bash
   ./run_tests.sh snowflake deps
   ./run_tests.sh snowflake debug
   ./run_tests.sh snowflake run
   ./run_tests.sh snowflake test
   ```

## Test Database Setup

### Snowflake Setup

1. Create a test database and schema:
   ```sql
   CREATE DATABASE IF NOT EXISTS DBT_MODEL_BUILD_LOGGER_TEST;
   CREATE SCHEMA IF NOT EXISTS DBT_MODEL_BUILD_LOGGER_TEST.TEST_SCHEMA;
   ```

2. Grant necessary permissions:
   ```sql
   GRANT USAGE ON DATABASE DBT_MODEL_BUILD_LOGGER_TEST TO ROLE YOUR_ROLE;
   GRANT USAGE ON SCHEMA DBT_MODEL_BUILD_LOGGER_TEST.TEST_SCHEMA TO ROLE YOUR_ROLE;
   GRANT CREATE TABLE ON SCHEMA DBT_MODEL_BUILD_LOGGER_TEST.TEST_SCHEMA TO ROLE YOUR_ROLE;
   GRANT CREATE VIEW ON SCHEMA DBT_MODEL_BUILD_LOGGER_TEST.TEST_SCHEMA TO ROLE YOUR_ROLE;
   ```

### Databricks Setup

1. Create a test catalog and schema:
   ```sql
   CREATE CATALOG IF NOT EXISTS dbt_model_build_reporter_test;
   CREATE SCHEMA IF NOT EXISTS dbt_model_build_reporter_test.test_schema;
   ```

2. Grant permissions:
   ```sql
   GRANT USE CATALOG ON CATALOG dbt_model_build_reporter_test TO `your_user@domain.com`;
   GRANT USE SCHEMA ON SCHEMA dbt_model_build_reporter_test.test_schema TO `your_user@domain.com`;
   GRANT CREATE TABLE ON SCHEMA dbt_model_build_reporter_test.test_schema TO `your_user@domain.com`;
   ```

### BigQuery Setup

1. Create a test dataset:
   ```bash
   bq mk --dataset your_project_id:dbt_model_build_reporter_test
   ```

2. Grant necessary permissions:
   ```bash
   bq update --source_format=NEWLINE_DELIMITED_JSON \
     --project_id=your_project_id \
     --dataset_id=dbt_model_build_reporter_test \
     --access_file=access.json
   ```

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure your test user has CREATE TABLE, CREATE VIEW, and DROP permissions
2. **Connection Timeout**: Check network connectivity and firewall settings
3. **Authentication Failed**: Verify credentials and token expiration
4. **Schema Not Found**: Ensure the test schema exists and is accessible

### Debug Mode

Run with debug logging:
```bash
cd integration_tests/test_project
dbt debug --target snowflake --log-level debug
```

### Clean Up

To clean up test artifacts:
```bash
./run_tests.sh snowflake clean
./run_tests.sh databricks clean
./run_tests.sh bigquery clean
```

## Security Best Practices

1. **Use Service Accounts**: Create dedicated service accounts for testing
2. **Minimal Permissions**: Grant only necessary permissions to test accounts
3. **Rotate Credentials**: Regularly rotate passwords and tokens
4. **Monitor Usage**: Monitor test database usage and costs
5. **Clean Up**: Always clean up test artifacts after testing

## Cost Management

- **Snowflake**: Use X-Small warehouse for testing
- **Databricks**: Use small SQL warehouse for testing
- **BigQuery**: Monitor query costs and use appropriate pricing tiers
