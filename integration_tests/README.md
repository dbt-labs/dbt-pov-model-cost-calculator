# Integration Tests

This directory contains integration tests for the `dbt_model_build_reporter` package to ensure it works correctly across different data warehouse adapters.

## Structure

```
integration_tests/
├── test_project/           # Basic dbt project for testing
│   ├── dbt_project.yml    # Test project configuration
│   ├── packages.yml       # Imports the main project
│   ├── models/            # Test models
│   └── tests/             # Test validations
├── profiles.yml           # Multi-adapter profile configuration
└── README.md             # This file
```

## Test Models

The integration tests include several test models to validate different materialization types:

- **`test_basic_model`**: Tests table materialization tracking
- **`test_view_model`**: Tests view materialization tracking  
- **`test_incremental_model`**: Tests incremental materialization tracking

## Test Validations

The tests validate:

1. **Artifact Table Creation**: Ensures the tracking table is created successfully
2. **Model Execution Logging**: Verifies that model executions are logged with correct metadata
3. **Cross-Adapter Compatibility**: Tests functionality across Snowflake, Databricks, and BigQuery

## Running Tests Locally

### Prerequisites

1. Install dbt and the required adapters:
   ```bash
   pip install dbt-core dbt-snowflake dbt-databricks dbt-bigquery
   ```

2. Set up environment variables for your target adapter:
   ```bash
   # Quick setup using the provided script
   ./setup_env.sh
   
   # Or manually create .env file from template
   cp env_template.txt .env
   # Edit .env with your actual values
   ```

3. The test runner script will automatically validate that all required environment variables are set for the specified adapter

### Running Tests

#### Using the Test Runner Script (Recommended)

```bash
# Navigate to integration tests directory
cd integration_tests

# Run full test suite for all adapters
./run_tests.sh all full

# Run tests for a specific adapter
./run_tests.sh snowflake full
./run_tests.sh databricks run
./run_tests.sh bigquery test
```

#### Manual dbt Commands

```bash
# Navigate to the test project
cd integration_tests/test_project

# Install dependencies (uses profiles.yml from parent directory)
dbt deps --profiles-dir ..

# Run tests for a specific adapter
dbt run --target snowflake --profiles-dir ..
dbt test --target snowflake --profiles-dir ..

# Or run for all adapters
dbt run --target snowflake --profiles-dir ..
dbt run --target databricks --profiles-dir ..
dbt run --target bigquery --profiles-dir ..
```

## GitHub Actions

The integration tests are automatically run on pull requests and pushes to main/develop branches via GitHub Actions. The workflow:

1. **Matrix Strategy**: Runs tests in parallel across Snowflake, Databricks, and BigQuery
2. **Environment Setup**: Configures Python and dbt dependencies
3. **Connection Testing**: Validates database connections
4. **Model Execution**: Runs test models and validates tracking
5. **Cleanup**: Removes test artifacts after completion

## Required Secrets

The GitHub Actions workflow requires the following secrets to be configured in your repository:

### Snowflake
- `SNOWFLAKE_ACCOUNT`
- `SNOWFLAKE_USER`
- `SNOWFLAKE_PASSWORD`
- `SNOWFLAKE_ROLE`
- `SNOWFLAKE_DATABASE`
- `SNOWFLAKE_WAREHOUSE`
- `SNOWFLAKE_SCHEMA`

### Databricks
- `DATABRICKS_HOST`
- `DATABRICKS_HTTP_PATH`
- `DATABRICKS_TOKEN`
- `DATABRICKS_SCHEMA`

### BigQuery
- `BIGQUERY_PROJECT`
- `BIGQUERY_DATASET`
- `BIGQUERY_KEYFILE`
- `BIGQUERY_LOCATION` (optional, defaults to 'US')

## Configuration

The test project uses the same configuration as the main project but with:

- **Smaller batch size** (100 instead of 500) for faster testing
- **Shorter time range** (7 days instead of 30) for query monitoring
- **Test-specific tags** to isolate test models
- **Query tags** for easy identification in system tables

## Troubleshooting

### Common Issues

1. **Connection Failures**: Verify environment variables and credentials
2. **Permission Errors**: Ensure test user has necessary permissions
3. **Schema Conflicts**: Use unique schema names for testing
4. **Timeout Issues**: Increase timeout values for large datasets

### Debug Mode

Run with debug logging to troubleshoot issues:

```bash
dbt debug --target <adapter> --profiles-dir .. --log-level debug
```

## Contributing

When adding new features to the main project:

1. Add corresponding test models if needed
2. Update test validations
3. Ensure tests pass across all adapters
4. Update this README if configuration changes
