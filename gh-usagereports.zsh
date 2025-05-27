#!/usr/bin/env zsh

# gh-usagereports.zsh - A tool to generate usage reports for GitHub Enterprise
# 
# This script helps enumerate organizations from a GitHub Enterprise instance and
# provides various reporting capabilities

# Set up colors for output
autoload -U colors && colors

# Default variables
GH_ENTERPRISE_URL=""
OUTPUT_FORMAT="table"
VERBOSE=false
MAX_ITEMS=100
OUTPUT_FILE=""

# Function to display usage information
usage() {
  echo "${fg[green]}GitHub Enterprise Usage Reports${reset_color}"
  echo "${fg[yellow]}Usage:${reset_color}"
  echo "  $0 [options]"
  echo ""
  echo "${fg[yellow]}Options:${reset_color}"
  echo "  ${fg[cyan]}-h, --help${reset_color}                Show this help message"
  echo "  ${fg[cyan]}-u, --url URL${reset_color}             GitHub Enterprise URL"
  echo "  ${fg[cyan]}-f, --format FORMAT${reset_color}       Output format (table, csv, json) [default: table]"
  echo "  ${fg[cyan]}-o, --output FILE${reset_color}         Output file (default: stdout)"
  echo "  ${fg[cyan]}-m, --max-items N${reset_color}         Maximum number of items to return [default: 100]"
  echo "  ${fg[cyan]}-v, --verbose${reset_color}             Enable verbose output"
  echo ""
  echo "${fg[yellow]}Examples:${reset_color}"
  echo "  $0 --url https://github.example.com"
  echo "  $0 --url https://github.example.com --format json --output orgs.json"
  echo ""
}

# Function to check if GitHub CLI is installed
check_gh_cli() {
  if ! command -v gh &> /dev/null; then
    echo "${fg[red]}Error: GitHub CLI not found${reset_color}"
    echo "Please install GitHub CLI: https://cli.github.com/manual/installation"
    exit 1
  fi
}

# Function to check GitHub Enterprise authentication
check_gh_auth() {
  local enterprise_url=$1
  
  # Configure GitHub CLI hostname if not default
  if [[ -n $enterprise_url ]]; then
    # Extract hostname from URL
    local hostname=$(echo $enterprise_url | sed -e 's|^https\?://||' -e 's|/.*$||')
    echo "${fg[yellow]}Setting GitHub Enterprise hostname to: $hostname${reset_color}"
    
    # Check if already authenticated to this hostname
    if ! gh auth status -h $hostname &> /dev/null; then
      echo "${fg[yellow]}Please authenticate to GitHub Enterprise${reset_color}"
      gh auth login -h $hostname
      
      # Check if authentication was successful
      if [ $? -ne 0 ]; then
        echo "${fg[red]}Authentication failed${reset_color}"
        exit 1
      fi
    fi
  fi
}

# Function to list organizations
list_organizations() {
  local enterprise_url=$1
  local max_items=$2
  local output_format=$3
  
  echo "${fg[blue]}Fetching organizations from GitHub Enterprise...${reset_color}"
  
  # Extract hostname from URL
  local hostname=""
  if [[ -n $enterprise_url ]]; then
    hostname=$(echo $enterprise_url | sed -e 's|^https\?://||' -e 's|/.*$||')
    host_param="-H $hostname"
  else
    host_param=""
  fi
  
  # Fetch organizations using GitHub CLI
  # The query fetches login, name, and repository count for each organization
  local query='
    query($endCursor: String) {
      organizations(first: 100, after: $endCursor) {
        nodes {
          login
          name
          repositories {
            totalCount
          }
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  '
  
  local result=$(gh api graphql $host_param -f query="$query")
  
  # Parse and format output based on the selected format
  case $output_format in
    json)
      echo $result | jq '.data.organizations.nodes'
      ;;
    csv)
      echo "login,name,repositories"
      echo $result | jq -r '.data.organizations.nodes[] | [.login, .name, .repositories.totalCount] | @csv'
      ;;
    table|*)
      echo "${fg[cyan]}Organization Name | Login | Repository Count${reset_color}"
      echo "${fg[cyan]}----------------- | ----- | ----------------${reset_color}"
      echo $result | jq -r '.data.organizations.nodes[] | "\(.name // "") | \(.login) | \(.repositories.totalCount)"' | \
        while IFS="|" read -r name login repos; do
          echo "$name | $login | $repos"
        done
      ;;
  esac
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -h|--help)
      usage
      exit 0
      ;;
    -u|--url)
      GH_ENTERPRISE_URL="$2"
      shift
      shift
      ;;
    -f|--format)
      OUTPUT_FORMAT="$2"
      shift
      shift
      ;;
    -o|--output)
      OUTPUT_FILE="$2"
      shift
      shift
      ;;
    -m|--max-items)
      MAX_ITEMS="$2"
      shift
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    *)
      echo "${fg[red]}Error: Unknown option $key${reset_color}"
      usage
      exit 1
      ;;
  esac
done

# Main execution
check_gh_cli

# Validate and set required parameters
if [[ -z $GH_ENTERPRISE_URL ]]; then
  echo "${fg[yellow]}Warning: GitHub Enterprise URL not specified.${reset_color}"
  echo "Using default GitHub instance."
fi

# Check authentication
check_gh_auth "$GH_ENTERPRISE_URL"

# Execute the requested operation
if [[ -n $OUTPUT_FILE ]]; then
  list_organizations "$GH_ENTERPRISE_URL" "$MAX_ITEMS" "$OUTPUT_FORMAT" > "$OUTPUT_FILE"
  echo "${fg[green]}Output written to $OUTPUT_FILE${reset_color}"
else
  list_organizations "$GH_ENTERPRISE_URL" "$MAX_ITEMS" "$OUTPUT_FORMAT"
fi

exit 0