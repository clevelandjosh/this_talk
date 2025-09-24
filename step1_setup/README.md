# Step 1: Environment Setup

This directory contains the setup scripts and Terraform configurations for the demo environment. The setup process creates Azure infrastructure including networking, monitoring, and Jira and CrowdStrike integrations. The services we use to as examples are deployed in step 4, so if you want to roll your own services instead you won't have a cluttered workspace. 

## 🎯 Overview

The setup creates:
- Azure Resource Group with hub-and-spoke network topology
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
        ├── azure-tenant/       # Azure tenant module
        │   ├── main.tf
        │   ├── outputs.tf
        │   └── variables.tf
        └── networking/         # Hub-and-spoke networking module
            └── locals.tf
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
| `VNET_ADDRESS_SPACE` | Virtual network address space (CIDR) | `10.209.96.0/19` |

### Optional Variables

The following variables have defaults but can be customized:

| Variable | Default | Description |
|----------|---------|-------------|
| `LOCATION` | `eastus` | Azure region for resources |
| `RESOURCE_PREFIX` | `secconf` | Prefix for Azure resource names |
| `ADMIN_USERNAME` | `azureadmin` | Admin username for VMs |

### Hub-and-Spoke Network Architecture

The networking configuration implements a sophisticated hub-and-spoke topology optimized for the default address space `10.209.96.0/19` (8,192 IPs). This design provides excellent scalability and security segmentation:

#### Network Topology Overview

| Component | Address Space | IP Count | Purpose |
|-----------|---------------|----------|---------|
| **Total Network** | `10.209.96.0/19` | 8,192 | Complete address space |
| **Hub VNet** | `10.209.96.0/22` | 1,024 | Central connectivity hub |
| **MCP Spoke** | `10.209.100.0/23` | 512 | Model Context Protocol servers |
| **AKS Spoke** | `10.209.104.0/22` | 1,024 | Azure Kubernetes Service |
| **VM Spoke** | `10.209.108.0/23` | 512 | Virtual machine workloads |
| **AI Spoke** | `10.209.112.0/22` | 1,024 | AI services and compute |

#### Detailed Subnet Allocation

**Hub VNet Subnets** (`10.209.96.0/22`):
- **Azure Firewall**: `10.209.96.0/26` (64 IPs)
- **Azure Bastion**: `10.209.96.64/27` (32 IPs)
- **VPN Gateway**: `10.209.96.96/27` (32 IPs)
- **Shared Services**: `10.209.97.0/24` (256 IPs)

**MCP Spoke Subnets** (`10.209.100.0/23`):
- **MCP Servers**: `10.209.100.0/25` (128 IPs)
- **Load Balancer**: `10.209.100.128/26` (64 IPs)

**AKS Spoke Subnets** (`10.209.104.0/22`):
- **AKS Nodes**: `10.209.104.0/23` (512 IPs)
- **AKS Pods**: `10.209.106.0/23` (512 IPs)

**VM Spoke Subnets** (`10.209.108.0/23`):
- **Application VMs**: `10.209.108.0/25` (128 IPs)
- **Management VMs**: `10.209.108.128/26` (64 IPs)

**AI Spoke Subnets** (`10.209.112.0/22`):
- **AI Services**: `10.209.112.0/24` (256 IPs)
- **AI Compute**: `10.209.113.0/24` (256 IPs)

#### Network Design Benefits

- **Security Segmentation**: Each spoke VNet is isolated with controlled communication through the hub
- **Scalability**: Room for growth within each segment while maintaining organization
- **Centralized Management**: Hub contains shared services like firewall, bastion, and VPN gateway
- **Optimized for Azure**: Subnet sizes align with Azure service requirements (AKS, Firewall, etc.)
- **Future-Proof**: Reserved address space allows for additional spokes and subnets

The system automatically calculates all subnet addresses using Terraform's CIDR functions, ensuring proper allocation and no overlapping ranges.

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
- **Hub-and-Spoke Network**: Multi-VNet architecture with proper segmentation
- **Log Analytics Workspace**: For monitoring and logging
- **MCP Servers**: Model Context Protocol servers for AI integrations
- **Demo Applications**: Jira and CrowdStrike integration demos

## 🔍 Validation

After setup completes, the script automatically validates that all required environment variables are properly set using [`validate_env.sh`](step1_setup/validate_env.sh).

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
- Hub-and-spoke network design provides security segmentation between workloads

## 🐛 Troubleshooting

### Common Issues

**Missing dependencies**: Ensure all prerequisite tools are installed and available in your PATH.

**Azure login issues**: Run `az login` and ensure you have appropriate permissions in the target subscription.

**Terraform state issues**: If Terraform state becomes corrupted, you may need to manually clean up the storage account and re-run setup.

**Permission errors**: Ensure your Azure account has sufficient permissions to create resources and service principals.

**Network addressing conflicts**: The default address space is optimized for `10.209.96.0/19`. If you need different addressing, review the [`networking/locals.tf`](step1_setup/terraform/modules/networking/locals.tf) file.

### Getting Help

If you encounter issues:
1. Check the error messages in the terminal output
2. Verify your Azure credentials and permissions
3. Ensure all dependencies are properly installed
4. Review the generated `.env` file for correctness
5. Check network address space conflicts if using custom addressing

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