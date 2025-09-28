# Azure Infrastructure Setup Guide

This repository contains scripts and configurations for setting up Azure infrastructure using a two-step process with proper security controls and infrastructure as code.

## Prerequisitesgit 

- Azure CLI installed and updated
- GitHub CLI installed
- Terraform CLI installed
- `jq` command-line tool installed
- Azure subscription with Contributor access
- GitHub repository access with admin rights

## Repository Structure

```
.
├── .github/                    # GitHub Actions workflows and setup
├── step0_account_and_github_setup/   # Initial Azure and GitHub configuration
└── step1_setup/               # Infrastructure deployment scripts
```

## Setup Process

### Step 0: Account and Initial Setup

This step configures Azure authentication, creates service principals, and sets up GitHub secrets.

```bash
cd step0_account_and_github_setup
./setup_step0.sh
```

This script will:
1. Check dependencies and Azure authentication
2. Create custom Azure roles
3. Create service principals with least privilege
4. Configure GitHub secrets
5. Set up Terraform backend access

### Step 1: Infrastructure Deployment

After Step 0 completes successfully, proceed with infrastructure deployment:

```bash
cd ../step1_setup
./setup.sh
```

This script will:
1. Validate environment
2. Create backend resources
3. Initialize Terraform
4. Deploy infrastructure

## Validation

Run tests to verify setup:

```bash
# Test Step 0 configuration
cd step0_account_and_github_setup
./run_tests.sh

# Test Step 1 setup
cd ../step1_setup
./test_integration.sh
```

## Directory Documentation

For detailed information about each step, refer to:

1. [Initial Setup Documentation](./step0_account_and_github_setup/README.md)
2. [Infrastructure Setup Documentation](./step1_setup/README.md)
3. [GitHub Actions Documentation](./.github/README.md)

## Security Notes

- Administrator credentials are stored locally in `~/.config/azure-setup/`
- Service principal credentials are stored in GitHub secrets
- Custom roles enforce least-privilege access
- Resource groups are scoped to specific workloads

## Troubleshooting

If you encounter issues:

1. Check Azure CLI authentication: `az account show`
2. Verify GitHub authentication: `gh auth status`
3. Confirm Terraform initialization: `terraform init`
4. Review logs in `~/.config/azure-setup/`

## Next Steps

After completing the setup:

1. Review created Azure resources in the portal
2. Verify GitHub Actions workflows
3. Test infrastructure access
4. Configure monitoring and alerts

## Contributing

Please read [CONTRIBUTING.md](./CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.