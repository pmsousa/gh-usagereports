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
DETAILED_REPOS=false
MAX_REPOS=50
ENV_FILE=".env"  # Default .env file path
GITHUB_TOKEN=""   # Will be loaded from .env if available
GITHUB_USERNAME="" # Will be loaded from .env if available

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
  echo "  ${fg[cyan]}-d, --detailed${reset_color}            Get detailed repository information for each organization"
  echo "  ${fg[cyan]}-r, --max-repos N${reset_color}         Maximum number of repositories per organization [default: 50]"
  echo "  ${fg[cyan]}-v, --verbose${reset_color}             Enable verbose output"
  echo "  ${fg[cyan]}--env-file FILE${reset_color}           Path to .env file with GitHub API token [default: .env]"
  echo ""
  echo "${fg[yellow]}Examples:${reset_color}"
  echo "  $0 --url https://github.example.com"
  echo "  $0 --url https://github.example.com --format json --output orgs.json"
  echo "  $0 --url https://github.example.com --detailed --max-repos 100"
  echo "  $0 --url https://github.example.com --detailed --format csv --output detailed_repos.csv"
  echo "  $0 --env-file ./custom.env --url https://github.example.com"
  echo ""
}

# Function to load environment variables from a .env file
load_env_file() {
  local env_file=$1

  if [[ -f "$env_file" ]]; then
    if [[ $VERBOSE == true ]]; then
      echo "${fg[yellow]}Loading environment variables from $env_file${reset_color}"
    fi
    
    # Read the .env file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
      # Skip comments and empty lines
      if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
        continue
      fi
      
      # Remove leading/trailing whitespace and export the variable
      line=$(echo "$line" | xargs)
      # Zsh pattern matching is different from Bash
      if [[ "$line" == [A-Za-z0-9_]*=* ]]; then
        # Extract key and value using parameter expansion
        local key="${line%%=*}"
        local value="${line#*=}"
        
        # Remove quotes if present
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        
        # Export the variable
        export "$key"="$value"
        
        if [[ $VERBOSE == true ]]; then
          if [[ "$key" == *TOKEN* || "$key" == *SECRET* || "$key" == *KEY* || "$key" == *PASSWORD* ]]; then
            echo "${fg[yellow]}Loaded $key=********${reset_color}"
          else
            echo "${fg[yellow]}Loaded $key=$value${reset_color}"
          fi
        fi
      fi
    done < "$env_file"
  else
    if [[ $VERBOSE == true ]]; then
      echo "${fg[yellow]}Environment file $env_file not found${reset_color}"
    fi
    return 1
  fi
  
  return 0
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
    
    # Set GH_HOST environment variable
    export GH_HOST="$hostname"
    
    # Check if we have a GitHub token from environment variables (loaded from .env)
    if [[ -n $GITHUB_TOKEN ]]; then
      if [[ $VERBOSE == true ]]; then
        if [[ -n $GITHUB_USERNAME ]]; then
          echo "${fg[yellow]}Using GitHub token for user: $GITHUB_USERNAME${reset_color}"
        else
          echo "${fg[yellow]}Using GitHub token from environment variable${reset_color}"
          echo "${fg[yellow]}Hint: Adding GITHUB_USERNAME to your .env file may help with authentication${reset_color}"
        fi
      fi
      # Set the token for GitHub CLI
      export GH_TOKEN="$GITHUB_TOKEN"
      
      # Verify the token works
      if ! gh auth status &> /dev/null; then
        echo "${fg[red]}Authentication failed using the provided token${reset_color}"
        
        # Check for common issues
        if [[ -z $GITHUB_USERNAME ]]; then
          echo "${fg[yellow]}Hint: Adding GITHUB_USERNAME to your .env file may help with authentication${reset_color}"
        fi
        
        # Try to get more detailed error information
        gh_error=$(gh auth status 2>&1)
        echo "${fg[red]}Error details: ${gh_error}${reset_color}"
        
        echo "${fg[yellow]}Falling back to regular GitHub CLI authentication...${reset_color}"
        # Clear the potentially invalid token
        unset GH_TOKEN
        
        # Continue with regular CLI authentication
        if ! gh auth status &> /dev/null; then
          echo "${fg[yellow]}Please authenticate to GitHub Enterprise: $hostname${reset_color}"
             # If we have a username, show it as a hint but don't try to use it directly
        if [[ -n $GITHUB_USERNAME ]]; then
          echo "${fg[yellow]}Hint: Use $GITHUB_USERNAME as your username when prompted${reset_color}"
        fi
        
        # Use web-based authentication with appropriate scopes
        if [[ $VERBOSE == true ]]; then
          gh auth login --hostname $hostname --web --scopes "repo,read:org"
        else
          gh auth login --hostname $hostname --web --scopes "repo,read:org" &> /dev/null
        fi
          
          # Check if authentication was successful
          if [ $? -ne 0 ]; then
            echo "${fg[red]}Authentication failed${reset_color}"
            exit 1
          fi
        fi
      else
        if [[ $VERBOSE == true ]]; then
          echo "${fg[green]}Successfully authenticated using API token${reset_color}"
        fi
      fi
    else
      # No API key found, use regular GitHub CLI authentication
      if [[ $VERBOSE == true ]]; then
        echo "${fg[yellow]}No GITHUB_TOKEN found in environment variables${reset_color}"
        echo "${fg[yellow]}Using regular GitHub CLI authentication${reset_color}"
      fi
      
      if ! gh auth status &> /dev/null; then
        echo "${fg[yellow]}Please authenticate to GitHub Enterprise: $hostname${reset_color}"
        
        # If we have a username, show it as a hint but don't try to use it directly
        if [[ -n $GITHUB_USERNAME ]]; then
          echo "${fg[yellow]}Hint: Use $GITHUB_USERNAME as your username when prompted${reset_color}"
        fi
        
        # Use web-based authentication with appropriate scopes
        if [[ $VERBOSE == true ]]; then
          gh auth login --hostname $hostname --web --scopes "repo,read:org"
        else
          gh auth login --hostname $hostname --web --scopes "repo,read:org" &> /dev/null
        fi        gh auth login --hostname <valtech-github-hostname> --with-token
        
        # Check if authentication was successful
        if [ $? -ne 0 ]; then
          echo "${fg[red]}Authentication failed${reset_color}"
          exit 1
        fi
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
    # For the gh api command, we need to set the hostname differently
    # The gh auth uses --hostname flag, but gh api uses the -H flag for headers or the host flag
    export GH_HOST="$hostname"
    if [[ $VERBOSE == true ]]; then
      echo "${fg[yellow]}Setting GH_HOST environment variable to: $hostname${reset_color}"
    fi
  fi
  
  # Fetch organizations using GitHub CLI
  # The query differs between GitHub.com and GitHub Enterprise
  local query=''
  
  # Check if this is GitHub.com or Enterprise
  if [[ $hostname == "github.com" ]]; then
    # GitHub.com query - needs to use viewer.organizations
    query='
      query($first: Int!, $endCursor: String) {
        viewer {
          organizations(first: $first, after: $endCursor) {
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
      }
    '
  else
    # GitHub Enterprise query - can use organizations directly
    query='
      query($first: Int!, $endCursor: String) {
        organizations(first: $first, after: $endCursor) {
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
  fi
  
  if [[ $VERBOSE == true ]]; then
    echo "${fg[yellow]}Executing GraphQL query on host: $hostname${reset_color}"
  fi
  
  # Determine page size based on max_items
  local page_size=$max_items
  if [[ $page_size -gt 100 ]]; then
    page_size=100 # GitHub API has a limit of 100 items per page
  fi
  
  if [[ $VERBOSE == true ]]; then
    echo "${fg[yellow]}Using page size: $page_size${reset_color}"
  fi
  
  # Note: For the GraphQL API, we need to ensure the parameter is passed as a number, not a string
  # Use the -F flag (capital F) to pass an integer value
  local result=""
  if ! result=$(gh api graphql -f query="$query" -F first=$page_size 2>&1); then
    echo "${fg[red]}Error: Failed to fetch organizations${reset_color}"
    if [[ $VERBOSE == true ]]; then
      echo "API Response: $result"
    fi
    exit 1
  fi
  
  # Make sure the result is valid JSON
  if ! echo "$result" | jq empty 2>/dev/null; then
    echo "${fg[red]}Error: Invalid JSON response from GitHub API${reset_color}"
    if [[ $VERBOSE == true ]]; then
      echo "API Response: $result"
    fi
    exit 1
  fi
  
  # Check if the result contains error information
  if echo "$result" | jq -e '.errors' &>/dev/null; then
    echo "${fg[red]}Error: GitHub API returned an error${reset_color}"
    echo "$result" | jq '.errors'
    exit 1
  fi
  
  # Extract the organizations nodes based on whether this is GitHub.com or Enterprise
  local org_nodes=""
  if [[ $hostname == "github.com" ]]; then
    org_nodes=$(echo "$result" | jq -r '.data.viewer.organizations.nodes')
    if [[ $VERBOSE == true ]]; then
      echo "${fg[yellow]}Extracting data from GitHub.com response (viewer.organizations)${reset_color}"
    fi
  else
    org_nodes=$(echo "$result" | jq -r '.data.organizations.nodes')
    if [[ $VERBOSE == true ]]; then
      echo "${fg[yellow]}Extracting data from GitHub Enterprise response (organizations)${reset_color}"
    fi
  fi
  
  # Check if there are any organizations returned
  local org_count=$(echo "$org_nodes" | jq -r 'length')
  if [[ $org_count -eq 0 ]]; then
    echo "${fg[yellow]}No organizations found${reset_color}"
    return
  fi
  
  # Parse and format output based on the selected format
  case $output_format in
    json)
      # Return raw JSON for programmatic use or formatted JSON for direct output
      echo "$org_nodes"
      ;;
    csv)
      echo "login,name,repositories"
      echo "$org_nodes" | jq -r '.[] | [.login, .name // "", .repositories.totalCount] | @csv'
      ;;
    table|*)
      echo "${fg[cyan]}Organization Name | Login | Repository Count${reset_color}"
      echo "${fg[cyan]}----------------- | ----- | ----------------${reset_color}"
      echo "$org_nodes" | jq -r '.[] | "\(.name // "-") | \(.login) | \(.repositories.totalCount)"' | \
        while IFS="|" read -r name login repos; do
          # Trim whitespace
          name=$(echo "$name" | xargs)
          login=$(echo "$login" | xargs)
          repos=$(echo "$repos" | xargs)
          echo "$name | $login | $repos"
        done
      ;;
  esac
}

# Function to get detailed repository information for an organization
get_org_repository_details() {
  local org_login=$1
  local max_repos=$2
  local output_format=$3
  
  echo "${fg[blue]}Fetching repository details for ${org_login}...${reset_color}"
  
  # GraphQL query to get repository details
  local query='
    query($login: String!, $first: Int!) {
      organization(login: $login) {
        repositories(first: $first, orderBy: {field: UPDATED_AT, direction: DESC}) {
          totalCount
          nodes {
            name
            updatedAt
            diskUsage
            defaultBranchRef {
              target {
                ... on Commit {
                  committedDate
                  history(first: 1) {
                    edges {
                      node {
                        committedDate
                      }
                    }
                  }
                }
              }
            }
            collaborators {
              totalCount
            }
          }
        }
      }
    }
  '
  
  # Determine page size based on max_repos
  local page_size=$max_repos
  if [[ $page_size -gt 100 ]]; then
    page_size=100 # GitHub API has a limit of 100 items per page
  fi
  
  if [[ $VERBOSE == true ]]; then
    echo "${fg[yellow]}Fetching up to $page_size repositories for $org_login${reset_color}"
  fi
  
  # Execute the GraphQL query with proper error handling
  local result=""
  if ! result=$(gh api graphql -f query="$query" -F login="$org_login" -F first=$page_size 2>&1); then
    echo "${fg[red]}Error: Failed to fetch repository details for $org_login${reset_color}"
    if [[ $VERBOSE == true ]]; then
      echo "API Response: $result"
    fi
    return 1
  fi
  
  # Validate that the result is valid JSON
  if ! echo "$result" | jq empty 2>/dev/null; then
    echo "${fg[red]}Error: Invalid JSON response from GitHub API${reset_color}"
    if [[ $VERBOSE == true ]]; then
      echo "API Response: $result"
    fi
    return 1
  fi
  
  # Check if the result contains error information
  if echo "$result" | jq -e '.errors' &>/dev/null; then
    echo "${fg[red]}Error: GitHub API returned an error${reset_color}"
    echo "$result" | jq '.errors'
    return 1
  fi
  
  # Check if we have the expected data structure
  if ! echo "$result" | jq -e '.data.organization' &>/dev/null; then
    echo "${fg[red]}Error: Unexpected API response format${reset_color}"
    if [[ $VERBOSE == true ]]; then
      echo "API Response: $result"
    fi
    return 1
  fi
  
  # Extract repository nodes with proper error handling
  local repo_nodes=""
  local repo_count=0
  
  if ! repo_nodes=$(echo "$result" | jq -r '.data.organization.repositories.nodes'); then
    echo "${fg[red]}Error: Failed to extract repository data${reset_color}"
    return 1
  fi
  
  if ! repo_count=$(echo "$result" | jq -r '.data.organization.repositories.totalCount'); then
    # If we can't get the count, set it to the length of repo_nodes
    repo_count=$(echo "$repo_nodes" | jq -r 'length')
  fi
  
  # Check if there are any repositories returned
  if [[ $(echo "$repo_nodes" | jq -r 'length') -eq 0 ]]; then
    echo "${fg[yellow]}No repositories found for $org_login${reset_color}"
    return 0
  fi
  
  echo "${fg[green]}Found $repo_count repositories for $org_login (showing up to $page_size)${reset_color}"
  
  # Parse and format output based on the selected format
  case $output_format in
    json)
      echo "$repo_nodes" | jq -r '
        map({
          name: .name,
          lastActivity: (.defaultBranchRef.target.committedDate // "N/A"),
          activeUsers: (.collaborators.totalCount // 0),
          sizeKB: (.diskUsage // 0)
        })
      '
      ;;
    csv)
      echo "repository,last_activity,active_users,size_kb"
      echo "$repo_nodes" | jq -r '.[] | [
        .name,
        (.defaultBranchRef.target.committedDate // "N/A"),
        (.collaborators.totalCount // 0),
        (.diskUsage // 0)
      ] | @csv'
      ;;
    table|*)
      echo "${fg[cyan]}Repository | Last Activity | Active Users | Size (KB)${reset_color}"
      echo "${fg[cyan]}----------- | ------------ | ------------ | ---------${reset_color}"
      echo "$repo_nodes" | jq -r '.[] | [
        .name,
        (.defaultBranchRef.target.committedDate // "N/A"),
        (.collaborators.totalCount // 0),
        (.diskUsage // 0)
      ] | join(" | ")' | \
        while IFS="|" read -r name last_activity users size; do
          # Trim whitespace
          name=$(echo "$name" | xargs)
          last_activity=$(echo "$last_activity" | xargs)
          users=$(echo "$users" | xargs)
          size=$(echo "$size" | xargs)
          echo "$name | $last_activity | $users | $size"
        done
      ;;
  esac
  
  return 0
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
    -d|--detailed)
      DETAILED_REPOS=true
      shift
      ;;
    -r|--max-repos)
      MAX_REPOS="$2"
      shift
      shift
      ;;
    --env-file)
      ENV_FILE="$2"
      shift
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

# Load environment variables from .env file if it exists
if [[ -n $ENV_FILE ]]; then
  if load_env_file "$ENV_FILE"; then
    echo "${fg[green]}Loaded environment variables from $ENV_FILE${reset_color}"
  else
    echo "${fg[yellow]}Note: No .env file found at $ENV_FILE or unable to load it${reset_color}"
  fi
fi

# Validate and set required parameters
if [[ -z $GH_ENTERPRISE_URL ]]; then
  echo "${fg[yellow]}Warning: GitHub Enterprise URL not specified.${reset_color}"
  echo "Using default GitHub instance."
fi

# Check authentication
check_gh_auth "$GH_ENTERPRISE_URL"

# Execute the requested operation
if [[ $DETAILED_REPOS == true ]]; then
  # For detailed repo information, first get the list of orgs
  if [[ $VERBOSE == true ]]; then
    echo "${fg[yellow]}Getting detailed repository information for organizations${reset_color}"
  fi
  
  # When getting detailed repos, we need to suppress regular org output
  if [[ $VERBOSE == true ]]; then
    echo "${fg[yellow]}Silently fetching organizations list for detailed reporting...${reset_color}"
  fi
  
  # Call the function but capture the output - with a slight modification to the original function
  orgs_output=$(
    # We need to modify the list_organizations function's behavior temporarily
    # to not print the "Fetching organizations..." message
    # Use a subshell to avoid affecting the main script environment
    (
      # Define a temporary function that behaves like the original but with silent output
      _silent_list_orgs() {
        local enterprise_url=$1
        local max_items=$2
        
        # Extract hostname from URL
        local hostname=""
        if [[ -n $enterprise_url ]]; then
          hostname=$(echo $enterprise_url | sed -e 's|^https\?://||' -e 's|/.*$||')
          export GH_HOST="$hostname"
        fi
        
        # Fetch organizations using GitHub CLI - same logic as the original function
        local query=''
        if [[ $hostname == "github.com" ]]; then
          query='
            query($first: Int!, $endCursor: String) {
              viewer {
                organizations(first: $first, after: $endCursor) {
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
            }
          '
        else
          query='
            query($first: Int!, $endCursor: String) {
              organizations(first: $first, after: $endCursor) {
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
        fi
        
        # Determine page size based on max_items
        local page_size=$max_items
        if [[ $page_size -gt 100 ]]; then
          page_size=100 # GitHub API has a limit of 100 items per page
        fi
        
        # Execute the query silently
        local result=""
        if ! result=$(gh api graphql -f query="$query" -F first=$page_size 2>&1); then
          echo "{}" # Return empty JSON on error
          return 1
        fi
        
        # Check if the result contains error information
        if echo "$result" | jq -e '.errors' &>/dev/null; then
          echo "{}" # Return empty JSON on error
          return 1
        fi
        
        # Extract the organizations nodes based on whether this is GitHub.com or Enterprise
        local org_nodes=""
        if [[ $hostname == "github.com" ]]; then
          org_nodes=$(echo "$result" | jq -r '.data.viewer.organizations.nodes')
        else
          org_nodes=$(echo "$result" | jq -r '.data.organizations.nodes')
        fi
        
        # Return just the JSON nodes
        echo "$org_nodes"
      }
      
      # Call our temporary function
      _silent_list_orgs "$GH_ENTERPRISE_URL" "$MAX_ITEMS"
    )
  )
  
  # Make sure we have JSON output by validating it
  if ! echo "$orgs_output" | jq empty 2>/dev/null; then
    echo "${fg[red]}Failed to parse organizations data. Please try again or use verbose mode for details.${reset_color}"
    if [[ $VERBOSE == true ]]; then
      echo "${fg[yellow]}Raw organizations output:${reset_color}"
      echo "$orgs_output"
    fi
    exit 1
  fi
  
  # Make sure we actually have some organizations
  if [[ $(echo "$orgs_output" | jq -r '. | length') -eq 0 ]]; then
    echo "${fg[yellow]}No organizations found. Cannot proceed with detailed reporting.${reset_color}"
    exit 0
  fi
  
  # Extract organization logins from JSON output into a proper zsh array
  org_logins=()
  while IFS= read -r login; do
    # Only add non-empty logins to the array
    if [[ -n "$login" ]]; then
      org_logins+=("$login")
    fi
  done < <(echo "$orgs_output" | jq -r '.[] | .login')
  
  if [[ $VERBOSE == true ]]; then
    echo "${fg[yellow]}Found ${#org_logins} organizations${reset_color}"
  fi
  
  # Process each organization
  if [[ -n $OUTPUT_FILE ]]; then
    # Create or truncate the output file
    > "$OUTPUT_FILE"
    
    # Write header based on format
    case $OUTPUT_FORMAT in
      csv)
        echo "organization,repository,last_activity,active_users,size_kb" > "$OUTPUT_FILE"
        ;;
      json)
        echo "[" > "$OUTPUT_FILE"
        ;;
    esac
    
    # Process each organization
    first_org=true
    for org in "${org_logins[@]}"; do
      echo "${fg[cyan]}Processing organization: $org${reset_color}"
      
      # Get repo details for the organization and capture the output
  # We need to ensure we handle errors properly
  repo_details=$(get_org_repository_details "$org" "$MAX_REPOS" "$OUTPUT_FORMAT")
  repo_status=$?
  
  # Check if the command was successful
  if [[ $repo_status -ne 0 ]]; then
    echo "${fg[red]}Failed to fetch repository details for $org. Skipping...${reset_color}"
    continue
  fi
  
  # For JSON output, validate that the output is valid JSON
  if [[ $OUTPUT_FORMAT == "json" ]]; then
    if ! echo "$repo_details" | jq empty 2>/dev/null; then
      echo "${fg[red]}Invalid JSON output for $org. Skipping...${reset_color}"
      if [[ $VERBOSE == true ]]; then
        echo "${fg[yellow]}Raw output:${reset_color}"
        echo "$repo_details"
      fi
      continue
    fi
  fi
      
      # Format and append to the output file based on format
      case $OUTPUT_FORMAT in
        csv)
          # For CSV, prefix each line with the organization name
          echo "$repo_details" | grep -v "^repository" | while read -r line; do
            echo "$org,$line" >> "$OUTPUT_FILE"
          done
          ;;
        json)
          # For JSON, wrap each repository with its organization
          if [[ $first_org == true ]]; then
            first_org=false
          else
            echo "," >> "$OUTPUT_FILE"
          fi
          
          # Make sure we have valid JSON before trying to transform it
          if echo "$repo_details" | jq empty 2>/dev/null; then
            repo_json=$(echo "$repo_details" | jq -c --arg org "$org" \
              'map({organization: $org} + .)')
            
            # Only write if we have valid JSON
            if [[ $? -eq 0 ]]; then
              echo "$repo_json" | tr -d '[]' >> "$OUTPUT_FILE"
            else
              echo "${fg[red]}Error formatting JSON for $org. Skipping...${reset_color}"
            fi
          else
            echo "${fg[red]}Invalid JSON data for $org. Skipping...${reset_color}"
            if [[ $VERBOSE == true ]]; then
              echo "${fg[yellow]}Raw output:${reset_color}"
              echo "$repo_details"
            fi
          fi
          ;;
        table|*)
          # For table, add a header for the organization
          echo "\n${fg[green]}Organization: $org${reset_color}" >> "$OUTPUT_FILE"
          echo "$repo_details" >> "$OUTPUT_FILE"
          ;;
      esac
    done
    
    # Close JSON array if needed
    if [[ $OUTPUT_FORMAT == "json" ]]; then
      echo "]" >> "$OUTPUT_FILE"
    fi
    
    echo "${fg[green]}Detailed repository information written to $OUTPUT_FILE${reset_color}"
  else
    # Output to stdout
    for org in "${org_logins[@]}"; do
      echo "\n${fg[green]}Organization: $org${reset_color}"
      get_org_repository_details "$org" "$MAX_REPOS" "$OUTPUT_FORMAT"
    done
  fi
else
  # Just list organizations without detailed repo info
  if [[ -n $OUTPUT_FILE ]]; then
    # Ensure we handle potential errors from list_organizations
    if list_organizations "$GH_ENTERPRISE_URL" "$MAX_ITEMS" "$OUTPUT_FORMAT" > "$OUTPUT_FILE"; then
      echo "${fg[green]}Output written to $OUTPUT_FILE${reset_color}"
    else
      echo "${fg[red]}Error occurred while writing to $OUTPUT_FILE${reset_color}"
    fi
  else
    # Execute directly to stdout
    list_organizations "$GH_ENTERPRISE_URL" "$MAX_ITEMS" "$OUTPUT_FORMAT"
  fi
fi

exit 0