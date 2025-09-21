# GitHub Actions Terraform CI/CD Setup

This document explains how to configure GitHub Actions for automated Terraform deployments when changes are made to the `step1_setup/terraform/` directory.

## 🔧 Workflow Overview

The GitHub Actions workflow (`terraform-cd.yml`) provides:

- **Validation**: Terraform format checking and validation on all changes
- **Plan**: Generates execution plans for pull requests and develop branch pushes
- **Apply**: Automatically applies changes when merged to main branch
- **Destroy**: Manual destruction of resources via workflow dispatch
- **PR Comments**: Adds Terraform plan output to pull request comments

## 🎯 Trigger Conditions

| Event | Condition | Action |
|-------|-----------|---------|
| **Pull Request** | Changes to `step1_setup/terraform/**` | Validate + Plan |
| **Push to main** | Changes to `step1_setup/terraform/**` | Validate + Plan + Apply |
| **Push to develop** | Changes to `step1_setup/terraform/**` | Validate + Plan |
| **Manual Dispatch** | Workflow dispatch with action choice | Plan, Apply, or Destroy |

## 🔐 Required GitHub Secrets

### Azure Authentication
Configure these secrets in your GitHub repository settings (`Settings > Secrets and variables > Actions`):

| Secret Name | Description | Example/Notes |
|-------------|-------------|---------------|
| `AZURE_CLIENT_ID` | Service Principal Application ID | `12345678-1234-1234-1234-123456789012` |
| `AZURE_CLIENT_SECRET` | Service Principal Secret | Generated during SP creation |
| `AZURE_TENANT_ID` | Azure Active Directory Tenant ID | `12345678-1234-1234-1234-123456789012` |
| `AZURE_SUBSCRIPTION_ID` | Target Azure Subscription ID | `12345678-1234-1234-1234-123456789012` |

### Terraform Backend Configuration
| Secret Name | Description | Example/Notes |
|-------------|-------------|---------------|
| `TF_STATE_STORAGE_ACCOUNT_NAME` | Storage account for Terraform state | `secconftfstate` |
| `TF_STATE_CONTAINER_NAME` | Blob container name | `tfstate` |
| `TF_STATE_KEY` | State file name | `terraform.tfstate` |

### Application Configuration
| Secret Name | Description | Required |
|-------------|-------------|----------|
| `ADMIN_EMAIL` | Administrator email address | ✅ |
| `ADMIN_PASSWORD` | Administrator password | ✅ |
| `JIRA_ADMIN_EMAIL` | Jira demo admin email | ✅ |
| `CROWDSTRIKE_API_KEY` | CrowdStrike API key | ✅ |
| `MCP_SERVER_COUNT` | Number of MCP servers | ❌ (default: 2) |
| `LOCATION` | Azure region | ❌ (default: eastus) |
| `RESOURCE_PREFIX` | Resource naming prefix | ❌ (default: secconf) |

## 🏗️ Environment Protection

The workflow uses GitHub Environment protection rules:

### Production Environment
- **Required for**: Apply operations on main branch
- **Recommended settings**:
  - Required reviewers
  - Wait timer (e.g., 5 minutes)
  - Deployment branches: main only

### Destruction Environment  
- **Required for**: Destroy operations
- **Recommended settings**:
  - Required reviewers (multiple)
  - Wait timer (e.g., 10 minutes)
  - Manual approval only

## 🚀 Setup Instructions

You can set up the GitHub Actions workflow either automatically using our interactive script or manually following the step-by-step instructions below.

### Option A: Automated Setup (Recommended)

Use the interactive setup script that handles all configuration automatically:

```bash
# Navigate to the .github directory
cd .github

# Run the interactive setup script
./setup-github-actions.sh
```

The script will:
- ✅ Check all dependencies (Azure CLI, GitHub CLI, jq)
- ✅ Verify Azure and GitHub authentication
- ✅ Prompt for all required configuration values
- ✅ Create Azure Service Principal automatically
- ✅ Configure storage account permissions
- ✅ Set all GitHub repository secrets
- ✅ Provide environment setup instructions
- ✅ Generate configuration files for reference

**Prerequisites for automated setup:**
- Azure CLI installed and logged in
- GitHub CLI installed and logged in
- jq installed for JSON processing

### Option B: Manual Setup

Follow these step-by-step instructions for manual configuration:

#### 1. Create Service Principal

```bash
# Create service principal for GitHub Actions
az ad sp create-for-rbac \
  --name "github-actions-terraform" \
  --role "Contributor" \
  --scopes "/subscriptions/{subscription-id}" \
  --sdk-auth
```

#### 2. Configure Storage Account Permissions

```bash
# Grant storage permissions to service principal
az role assignment create \
  --assignee {client-id} \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Storage/storageAccounts/{storage-account-name}"
```

#### 3. Add GitHub Secrets

Navigate to your repository and add all required secrets:
- `Settings > Secrets and variables > Actions > New repository secret`

#### 4. Configure Environments

Create protection rules for environments:
- `Settings > Environments > New environment`
- Add protection rules as described above

#### 5. Enable Workflows

Ensure GitHub Actions are enabled:
- `Settings > Actions > General > Allow all actions and reusable workflows`

## 📋 Workflow Jobs Breakdown

### `terraform-validate`
- Runs on all trigger events
- Checks Terraform formatting
- Validates syntax and configuration
- No Azure credentials required

### `terraform-plan` 
- Runs on PRs, develop pushes, and manual plan requests
- Authenticates to Azure
- Generates execution plan
- Comments plan on PR (if applicable)
- Uploads plan artifact for apply job

### `terraform-apply`
- Runs on main branch pushes and manual apply requests
- Requires production environment approval
- Downloads plan from previous job
- Applies infrastructure changes
- Uploads outputs as artifacts

### `terraform-destroy`
- Manual workflow dispatch only
- Requires destruction environment approval
- Destroys all managed infrastructure
- **⚠️ Use with extreme caution**

## 🔍 Monitoring and Troubleshooting

### View Workflow Runs
- Navigate to `Actions` tab in GitHub repository
- Select `Terraform CI/CD` workflow
- View individual run details and logs

### Common Issues

**Authentication Failures**:
- Verify service principal credentials
- Check subscription and tenant IDs
- Ensure SP has required permissions

**Backend Access Issues**:
- Verify storage account name and container
- Check SP has Storage Blob Data Contributor role
- Ensure backend configuration matches setup

**Plan/Apply Failures**:
- Review Terraform error messages in job logs
- Check variable values and types
- Verify Azure quota and permissions

### Debugging Tips

1. **Enable debug logging**: Add `TF_LOG: DEBUG` to job environment variables
2. **Manual validation**: Run `terraform validate` and `terraform plan` locally
3. **Check artifacts**: Download plan artifacts to review locally
4. **Review state**: Ensure Terraform state is not corrupted

## 🔄 Workflow Usage Examples

### Standard Development Flow

1. **Create feature branch**: `git checkout -b feature/update-network`
2. **Make Terraform changes**: Edit files in `step1_setup/terraform/`
3. **Push changes**: Creates PR and triggers plan
4. **Review plan**: Check PR comment for plan output
5. **Merge to main**: Triggers apply workflow

### Manual Operations

**Run Plan Only**:
1. Go to `Actions > Terraform CI/CD > Run workflow`
2. Select branch and action: `plan`
3. Review execution in Actions tab

**Emergency Destroy**:
1. Go to `Actions > Terraform CI/CD > Run workflow`  
2. Select action: `destroy`
3. Approve in destruction environment
4. Monitor execution carefully

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform GitHub Actions](https://learn.hashicorp.com/tutorials/terraform/github-actions)
- [Azure Service Principal Setup](https://docs.microsoft.com/en-us/azure/developer/github/connect-from-azure)
- [GitHub Environment Protection](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)