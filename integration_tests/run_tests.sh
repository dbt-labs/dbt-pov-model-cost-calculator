#!/bin/bash

# Integration Test Runner for dbt_model_build_reporter
# Usage: ./run_tests.sh [-c command] [adapter] [test_command]
# Options:
#   -c command    Choose between 'dbt' or 'dbtf' (default: dbt)
# Adapters: snowflake, databricks, bigquery, all
# Commands: deps, debug, compile, run, test, clean

set -e

# Enable alias expansion for non-interactive shells
shopt -s expand_aliases

# Define dbtf alias early in the script
alias dbtf="$HOME/.local/bin/dbt"

# Function to resolve the actual command to use
resolve_dbt_command() {
    local cmd=$1
    case $cmd in
        "dbtf")
            echo "$HOME/.local/bin/dbt"
            ;;
        "dbt")
            echo "dbt"
            ;;
        *)
            echo "$cmd"
            ;;
    esac
}

# Default command
DBT_COMMAND="dbt"

# Parse optional arguments
while getopts ":c:" opt; do
  case ${opt} in
    c )
      DBT_COMMAND=$OPTARG
      ;;
    \? )
      echo "Usage: $0 [-c command] [adapter] [test_command]"
      echo "Options:"
      echo "  -c command    Choose between 'dbt' or 'dbtf' (default: dbt)"
      echo "Adapters: snowflake, databricks, bigquery, all"
      echo "Commands: deps, debug, compile, run, test, clean"
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "Error: .env file not found!"
    echo "Please run ./setup_env.sh first to create your .env file."
    exit 1
fi

# Enable automatic export of variables
set -o allexport
export DBT_CLOUD_RUN_ID="$(date +%s)"
export DBT_CLOUD_JOB_ID="integration_test_run"
# Source the .env file
source .env

# Disable automatic export to prevent unintended exports
set +o allexport

# Print status about environment loading
echo "Environment variables loaded from .env file"
echo "=========================================="

ADAPTER=${1:-all}
COMMAND=${2:-full}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to validate environment variables for a specific adapter
validate_env_vars() {
    local adapter=$1
    local missing_vars=()
    
    case $adapter in
        "snowflake")
            required_vars=("SNOWFLAKE_ACCOUNT" "SNOWFLAKE_USER" "DBT_ENV_SECRET_SNOWFLAKE_PASSWORD" "SNOWFLAKE_ROLE" "SNOWFLAKE_DATABASE" "SNOWFLAKE_WAREHOUSE" "SNOWFLAKE_SCHEMA")
            ;;
        "databricks")
            required_vars=("DATABRICKS_HOST" "DATABRICKS_HTTP_PATH" "DBT_ENV_SECRET_DATABRICKS_TOKEN" "DATABRICKS_SCHEMA")
            ;;
        "bigquery")
            required_vars=("BIGQUERY_PROJECT" "BIGQUERY_DATASET" "BIGQUERY_CLIENT_X509_CERT_URL" )
            ;;
        *)
            return 0  # Skip validation for 'all' or unknown adapters
            ;;
    esac
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        print_error "Missing required environment variables for $adapter:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        echo
        print_status "Please check your .env file and ensure all required variables are set."
        return 1
    fi
    
    return 0
}

# Function to run dbt command for a specific adapter
run_dbt_command() {
    local adapter=$1
    local command=$2
    
    # Validate environment variables for the adapter
    if ! validate_env_vars $adapter; then
        return 1
    fi
    
    # Resolve the actual command to use
    local resolved_command=$(resolve_dbt_command "$DBT_COMMAND")
    
    print_status "Running $resolved_command $command for $adapter..."
    
    cd test_project
    
    case $command in
        "deps")
            $resolved_command deps --target $adapter --profiles-dir ..
            ;;
        "parse")
            $resolved_command parse --target $adapter --profiles-dir ..
            ;;
        "compile")
            $resolved_command compile --target $adapter --profiles-dir ..
            ;;
        "run")
            $resolved_command run --target $adapter --profiles-dir ..
            ;;
        "build")
            $resolved_command build --target $adapter --profiles-dir ..
            ;;
        "test")
            $resolved_command test --target $adapter --profiles-dir ..
            ;;
        "clean")
            $resolved_command run-operation query --args '{sql: "drop table if exists {{ var(\"artifact_table\", \"dbt_model_executions\") }}"}' --target $adapter --profiles-dir .. || true
            $resolved_command run-operation query --args '{sql: "drop table if exists test_basic_model"}' --target $adapter --profiles-dir .. || true
            $resolved_command run-operation query --args '{sql: "drop view if exists test_view_model"}' --target $adapter --profiles-dir .. || true
            $resolved_command run-operation query --args '{sql: "drop table if exists test_incremental_model"}' --target $adapter --profiles-dir .. || true
            ;;
        *)
            print_error "Unknown command: $command"
            exit 1
            ;;
    esac
    
    cd ..
    
    if [ $? -eq 0 ]; then
        print_success "$resolved_command $command completed successfully for $adapter"
    else
        print_error "$resolved_command $command failed for $adapter"
        exit 1
    fi
}

# Function to run full test suite for an adapter
run_full_test() {
    local adapter=$1
    
    print_status "Running full test suite for $adapter..."
    
    run_dbt_command $adapter "deps"
    run_dbt_command $adapter "parse"
    run_dbt_command $adapter "compile"
    run_dbt_command $adapter "run"
    
    print_success "Full test suite completed for $adapter"
}

# Main execution
print_status "Starting integration tests for dbt_model_build_logger"
print_status "Using command: $DBT_COMMAND"
print_status "Adapter: $ADAPTER, Test Command: $COMMAND"

# Check if we're in the right directory
if [ ! -f "test_project/dbt_project.yml" ]; then
    print_error "Please run this script from the integration_tests directory"
    exit 1
fi

# Handle different adapter options
case $ADAPTER in
    "snowflake"|"databricks"|"bigquery")
        if [ "$COMMAND" = "full" ]; then
            run_full_test $ADAPTER
        else
            run_dbt_command $ADAPTER $COMMAND
        fi
        ;;
    "all")
        print_status "Running tests for all adapters..."
        for adapter in snowflake databricks bigquery; do
            print_status "Testing $adapter..."
            if [ "$COMMAND" = "full" ]; then
                run_full_test $adapter
            else
                run_dbt_command $adapter $COMMAND
            fi
        done
        print_success "All adapter tests completed"
        ;;
    *)
        print_error "Unknown adapter: $ADAPTER"
        print_status "Available adapters: snowflake, databricks, bigquery, all"
        exit 1
        ;;
esac

print_success "Integration tests completed successfully!"
