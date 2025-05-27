# gh-usagereports

A tool for generating usage reports for GitHub repositories.

## Overview

gh-usagereports is designed to help analyze and report on GitHub Enterprise repository usage metrics, providing insights into number of repositories per organization, repository activity, user engagement, and other important statistics.

## Features

- Fetch repository statistics from GitHub Enterprise
- Generate detailed usage reports
- Track repository views and clones
- Analyze contributor activity
- Generate customizable reports
- Export data in multiple formats
- Support for API token authentication via .env file

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/gh-usagereports.git

# Navigate to the project directory
cd gh-usagereports

# Make the script executable
chmod +x gh-usagereports.zsh
```

## Usage

```bash
# Basic usage
./gh-usagereports.zsh --url https://github.example.com

# Generate a report for a specific time period
./gh-usagereports.zsh --url https://github.example.com --detailed

# Export report as CSV
./gh-usagereports.zsh --url https://github.example.com --format csv --output report.csv

# Use a specific .env file
./gh-usagereports.zsh --url https://github.example.com --env-file ./custom.env
```

## Configuration

Create a `.env` file in the project root with your GitHub credentials:

```
GITHUB_TOKEN=your_personal_access_token
```

A template file `.env.example` is provided for reference. Copy it to `.env` and add your token:

```bash
cp .env.example .env
# Edit .env with your favorite editor to add your token
```

## Options

```
Options:
  -h, --help                Show this help message
  -u, --url URL             GitHub Enterprise URL
  -f, --format FORMAT       Output format (table, csv, json) [default: table]
  -o, --output FILE         Output file (default: stdout)
  -m, --max-items N         Maximum number of items to return [default: 100]
  -d, --detailed            Get detailed repository information for each organization
  -r, --max-repos N         Maximum number of repositories per organization [default: 50]
  -v, --verbose             Enable verbose output
  --env-file FILE           Path to .env file with GitHub API token [default: .env]
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.