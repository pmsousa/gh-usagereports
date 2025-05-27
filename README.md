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

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/gh-usagereports.git

# Navigate to the project directory
cd gh-usagereports

# Install dependencies
npm install
```

## Usage

```bash
# Basic usage
gh-usagereports --repo owner/repository

# Generate a report for a specific time period
gh-usagereports --repo owner/repository --from 2023-01-01 --to 2023-12-31

# Export report as CSV
gh-usagereports --repo owner/repository --export csv
```

## Configuration

Create a `.env` file in the project root with your GitHub credentials:

```
GITHUB_TOKEN=your_personal_access_token
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

```bash
# Clone the repository
git clone https://github.com/yourusername/gh-usagereports.git

# Navigate to the project directory
cd gh-usagereports

# Install dependencies
npm install
```

## Usage

```bash
# Basic usage
gh-usagereports --repo owner/repository

# Generate a report for a specific time period
gh-usagereports --repo owner/repository --from 2023-01-01 --to 2023-12-31

# Export report as CSV
gh-usagereports --repo owner/repository --export csv
```

## Configuration

Create a `.env` file in the project root with your GitHub credentials:

```
GITHUB_TOKEN=your_personal_access_token
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.