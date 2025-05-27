#!/usr/bin/env zsh
# test_env_auth.zsh - Test for .env file authentication
#
# This script tests the .env file loading functionality

# Set default values
ENV_FILE=".env"
VERBOSE="false"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --env-file)
      ENV_FILE="$2"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE="true"
      shift
      ;;
    *)
      echo "Usage: $0 [--env-file FILE_PATH] [--verbose]"
      echo "  --env-file FILE_PATH : Path to the .env file to test (default: .env)"
      echo "  -v, --verbose        : Enable verbose output"
      exit 1
      ;;
  esac
done

# Check if the specified .env file exists
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Error: .env file not found at $ENV_FILE"
  echo "Please provide a valid .env file path with --env-file parameter"
  exit 1
fi

# Run the main script with verbose output and check for successful .env loading
echo "Testing .env file authentication with $ENV_FILE..."

# Get the directory of this script
SCRIPT_DIR=$(dirname "$0")
SCRIPT_PATH="$SCRIPT_DIR/gh-usagereports.zsh"

# Check if the main script exists
if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "❌ Error: gh-usagereports.zsh not found at $SCRIPT_PATH"
  echo "Make sure you're running this test from the correct directory"
  exit 1
fi

# Build the command
CMD="$SCRIPT_PATH --verbose --env-file $ENV_FILE"
if [[ $VERBOSE == "true" ]]; then
  echo "Running command: $CMD"
fi

# Run the script with the specified .env file
$CMD | grep "Using GitHub token from environment variable"

# Check the exit code
if [[ $? -eq 0 ]]; then
  echo "✅ Successfully loaded token from $ENV_FILE"
  exit 0
else
  echo "❌ Failed to load token from $ENV_FILE"
  exit 1
fi
