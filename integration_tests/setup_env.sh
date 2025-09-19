#!/bin/bash

# Setup script for integration test environment variables
# This script helps you create a .env file from the template

set -e

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

# Check if .env already exists
if [ -f ".env" ]; then
    print_warning ".env file already exists!"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Setup cancelled. Existing .env file preserved."
        exit 0
    fi
fi

# Check if template exists
if [ ! -f "env_template.txt" ]; then
    print_error "env_template.txt not found!"
    print_status "Please make sure you're running this script from the integration_tests directory."
    exit 1
fi

# Copy template to .env
print_status "Creating .env file from template..."
cp env_template.txt .env

print_success ".env file created successfully!"

print_warning "IMPORTANT: You need to edit the .env file and replace all 'your_*' placeholders with your actual values."

print_status "Required environment variables:"
echo
echo "SNOWFLAKE:"
echo "  - SNOWFLAKE_ACCOUNT"
echo "  - SNOWFLAKE_USER"
echo "  - DBT_ENV_SECRET_SNOWFLAKE_PASSWORD"
echo "  - SNOWFLAKE_ROLE"
echo "  - SNOWFLAKE_DATABASE"
echo "  - SNOWFLAKE_WAREHOUSE"
echo "  - SNOWFLAKE_SCHEMA"
echo
echo "DATABRICKS:"
echo "  - DATABRICKS_HOST"
echo "  - DATABRICKS_HTTP_PATH"
echo "  - DBT_ENV_SECRET_DATABRICKS_TOKEN"
echo "  - DATABRICKS_CATALOG"
echo "  - DATABRICKS_SCHEMA"
echo
echo "BIGQUERY:"
echo "  - BIGQUERY_PROJECT"
echo "  - BIGQUERY_DATASET"
echo "  - DBT_ENV_SECRET_BIGQUERY_KEYFILE"
echo "  - BIGQUERY_LOCATION (optional)"
echo

# Ask if user wants to edit the file
read -p "Would you like to open the .env file for editing now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Try to open with common editors
    if command -v code &> /dev/null; then
        print_status "Opening .env file with VS Code..."
        code .env
    elif command -v nano &> /dev/null; then
        print_status "Opening .env file with nano..."
        nano .env
    elif command -v vim &> /dev/null; then
        print_status "Opening .env file with vim..."
        vim .env
    else
        print_warning "No suitable editor found. Please edit .env manually."
    fi
fi

print_status "Next steps:"
echo "1. Edit the .env file with your actual credentials"
echo "2. Make sure your test user has the necessary permissions"
echo "3. Run the integration tests: ./run_tests.sh <adapter> full"
echo
print_warning "Remember: Never commit the .env file to version control!"
