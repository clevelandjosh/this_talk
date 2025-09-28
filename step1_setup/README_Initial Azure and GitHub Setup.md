# Initial Azure and GitHub Setup

This folder contains scripts for initial setup of Azure authentication and GitHub integration.

## Contents

- `azure-setup.sh`: Creates service principals and roles in Azure
- `common/`: Common functions used across scripts
  - `logging.sh`: Logging utilities
  - `validation.sh`: Input validation functions

## Setup Process

1. Run initial Azure setup:
```bash
./azure-setup.sh
```

This will:
- Create required Azure roles
- Setup service principals
- Configure GitHub secrets
- Setup Terraform backend access

## Next Steps

After completing this setup:
1. Navigate to ../step1_setup
2. Follow instructions to deploy infrastructure