# Step 1: Environment Setup

This directory contains the setup scripts and Terraform configurations for the ISS talk presentation demo environment. The setup process creates Azure infrastructure including networking, monitoring, and demo applications for Jira and CrowdStrike integrations.

## 🎯 Overview

The setup creates:
- Azure Resource Group with VNet and subnets
- Log Analytics workspace for monitoring
- Storage account for Terraform state management
- Service principal for Terraform authentication
- MCP (Model Context Protocol) servers
- Demo applications (Jira and CrowdStrike)

## 📋 Prerequisites

Before running the setup, ensure you have the following tools installed:

- **Azure CLI** (`az`) - For Azure resource management
- **Terraform** (`terraform`) - For infrastructure as code
- **jq** - For JSON processing
- **Bash** - Shell environment

### Installation Commands

```bash
# Install Azure CLI (macOS)
brew install azure-cli

# Install Terraform (macOS)
brew install terraform

# Install jq (macOS)
brew install jq
```

## 🚀 Quick Start

1. **Clone and navigate to setup directory**:
   ```bash
   cd step1_setup
   ```

2. **Login to Azure**:
   ```bash
   az login
   ```

3. **Run the setup script**:
   ```bash
   ./setup.sh
   ```

The script will prompt you for required configuration values and automatically create all necessary Azure resources.

## 📁 File Structure

```
step1_setup/
├── setup.sh                    # Main setup script
├── create_backend_resources.sh # Creates Terraform backend storage
├── validate_env.sh             # Validates environment variables
├── prompts.env.template        # Template for environment variables
├── README.md                   # This file
└── terraform/
    ├── main.tf                 # Main Terraform configuration
    ├── variables.tf            # Terraform variables
    └── modules/
        └── azure-tenant/       # Azure tenant module
            ├── main.tf
            ├── outputs.tf
            └── variables.tf
```

## ⚙️ Configuration

The setup process uses environment variables defined in a `.env` file. The script will prompt you for the following values:

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `ARM_CLIENT_ID` | Azure service principal client ID | `12345678-1234-1234-1234-123456789012` |
| `ARM_CLIENT_SECRET` | Azure service principal secret | `your-secret-value` |
| `ARM_SUBSCRIPTION_ID` | Azure subscription ID | `12345678-1234-1234-1234-123456789012` |
| `ARM_TENANT_ID` | Azure tenant ID | `12345678-1234-1234-1234-123456789012` |
| `JIRA_ADMIN_EMAIL` | Email for Jira demo admin | `admin@example.com` |
| `CROWDSTRIKE_API_KEY` | CrowdStrike API key for demo | `your-api-key` |
| `MCP_SERVER_COUNT` | Number of MCP servers to deploy | `2` |

### Optional Variables

The following variables have defaults but can be customized:

| Variable | Default | Description |
|----------|---------|-------------|
| `LOCATION` | `eastus` | Azure region for resources |
| `RESOURCE_PREFIX` | `secconf` | Prefix for Azure resource names |
| `ADMIN_USERNAME` | `azureadmin` | Admin username for VMs |

## 🔧 What the Setup Does

### 1. Dependency Check
Verifies that required tools (`terraform`, `az`, `jq`) are installed.

### 2. Environment Configuration
- Creates a `.env` file with your configuration
- Prompts for missing variables using the template

### 3. Backend Resource Creation
- Creates an Azure Storage Account for Terraform state
- Sets up a blob container for state files
- Creates a service principal with appropriate permissions
- Configures Terraform backend authentication

### 4. Infrastructure Deployment
The Terraform configuration creates:
- **Resource Group**: Container for all resources
- **Virtual Network**: Network infrastructure with subnets
- **Log Analytics Workspace**: For monitoring and logging
- **MCP Servers**: Model Context Protocol servers for AI integrations
- **Demo Applications**: Jira and CrowdStrike integration demos

## 🔍 Validation

After setup completes, the script automatically validates that all required environment variables are properly set using `validate_env.sh`.

## 🛠️ Manual Steps (if needed)

If you need to run components individually:

### Create Backend Resources Only
```bash
./create_backend_resources.sh
```

### Validate Environment Only
```bash
./validate_env.sh
```

### Run Terraform Manually
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## 🧹 Cleanup

To clean up resources created by this setup, see the `step5_teardown` directory in the parent repository.

## 🔒 Security Notes

- Service principal credentials are stored in `terraform-sp.json` - keep this file secure
- The `.env` file contains sensitive information - ensure it's not committed to version control
- Storage account uses `Standard_LRS` replication and blocks public blob access
- Service principal has minimal required permissions (Storage Blob Data Contributor)

## 🐛 Troubleshooting

### Common Issues

**Missing dependencies**: Ensure all prerequisite tools are installed and available in your PATH.

**Azure login issues**: Run `az login` and ensure you have appropriate permissions in the target subscription.

**Terraform state issues**: If Terraform state becomes corrupted, you may need to manually clean up the storage account and re-run setup.

**Permission errors**: Ensure your Azure account has sufficient permissions to create resources and service principals.

### Getting Help

If you encounter issues:
1. Check the error messages in the terminal output
2. Verify your Azure credentials and permissions
3. Ensure all dependencies are properly installed
4. Review the generated `.env` file for correctness

## 🤖 GitHub Actions CI/CD

This repository includes automated Terraform workflows for continuous deployment:

- **Automatic Planning**: Terraform plans are generated for all pull requests
- **Automatic Apply**: Changes merged to main branch are automatically applied
- **Manual Operations**: Support for manual plan, apply, and destroy operations

### Quick Setup

Use the automated setup script for easy configuration:

```bash
# Navigate to the .github directory
cd ../.github

# Run the interactive setup script
./setup-github-actions.sh
```

### Manual Setup

See [`.github/README.md`](../.github/README.md) for complete manual setup instructions including:
- Required GitHub secrets configuration
- Service principal setup
- Environment protection rules
- Workflow usage examples

## 📝 Next Steps

After successful setup, proceed to:
- `step2_integrations/` - Configure integrations
- `step3_ai_functionality/` - Set up AI features
- `step4_optional_resources/` - Add optional components