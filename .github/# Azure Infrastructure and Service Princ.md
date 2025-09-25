# Azure Infrastructure and Service Principal Architecture

## Service Principal Hierarchy
```mermaid
graph TD
    subgraph "Azure Subscription"
        Admin[Azure Administrator<br/>Full Contributor Rights]
        
        subgraph "Service Principals"
            SP1[Terraform State Manager]
            SP2[Network Infrastructure Manager]
            SP3[AI Foundry Manager]
            SP4[AKS Manager]
            SP5[VM Image Builder]
            SP6[Resource Group Manager]
        end
        
        Admin -->|Creates| SP1
        Admin -->|Creates| SP2
        Admin -->|Creates| SP3
        Admin -->|Creates| SP4
        Admin -->|Creates| SP5
        Admin -->|Creates| SP6
    end
```

## Resource Access and Permissions
```mermaid
graph LR
    subgraph "Storage Resources"
        SA[Storage Account<br/>tfstate]
        Container[Blob Container<br/>terraform.tfstate]
    end
    
    subgraph "Network Resources"
        VNET[Virtual Network]
        NSG[Network Security Groups]
        LB[Load Balancers]
        FW[Firewalls]
    end
    
    subgraph "Compute Resources"
        AKS[AKS Cluster]
        VMs[Virtual Machines]
        Images[VM Images]
    end
    
    subgraph "Service Principals"
        SP1[Terraform State Manager]
        SP2[Network Infrastructure Manager]
        SP3[AI Foundry Manager]
        SP4[AKS Manager]
        SP5[VM Image Builder]
        SP6[Resource Group Manager]
    end
    
    SP1 -->|Blob Data Contributor| SA
    SP2 -->|Network Contributor| VNET
    SP2 -->|Network Contributor| NSG
    SP2 -->|Network Contributor| LB
    SP2 -->|Network Contributor| FW
    SP4 -->|AKS Contributor| AKS
    SP5 -->|VM Contributor| VMs
    SP5 -->|VM Contributor| Images
    SP6 -->|Resource Group Contributor| ResourceGroups
```

## Resource Groups and Scoping
```mermaid
graph TD
    subgraph "Azure Subscription"
        RG1[TF State Resource Group]
        RG2[VM Workload Resource Group]
        RG3[AKS Workload Resource Group]
        
        subgraph "TF State RG Resources"
            SA[Storage Account]
            Container[State Container]
        end
        
        subgraph "VM RG Resources"
            VM1[Virtual Machines]
            IMG[VM Images]
            DISK[Managed Disks]
        end
        
        subgraph "AKS RG Resources"
            AKS[AKS Cluster]
            AKSVNET[AKS VNet]
            AKSLB[AKS Load Balancer]
        end
    end
```

## GitHub Integration
```mermaid
graph LR
    subgraph "GitHub Repository"
        GHA[GitHub Actions]
        ENV1[Production Environment]
        ENV2[Destruction Environment]
        SEC[GitHub Secrets]
    end
    
    subgraph "Azure Resources"
        SP[Service Principals]
        RG[Resource Groups]
        Resources[Azure Resources]
    end
    
    GHA -->|Uses| SEC
    SEC -->|Contains| SP
    SP -->|Manages| Resources
    ENV1 -->|Controls| GHA
    ENV2 -->|Controls| GHA
```

## Custom Role Definitions
```mermaid
graph TD
    subgraph "Custom Azure Roles"
        R1[Network Infrastructure<br/>Contributor]
        R2[AI Foundry<br/>Contributor]
        R3[VM Image Builder<br/>Contributor]
    end
    
    subgraph "Built-in Roles"
        BR1[Storage Blob Data<br/>Contributor]
        BR2[AKS Contributor]
        BR3[Network Contributor]
    end
    
    subgraph "Service Principals"
        SP1[Terraform State Manager]
        SP2[Network Infrastructure Manager]
        SP3[AI Foundry Manager]
        SP4[AKS Manager]
        SP5[VM Image Builder]
        SP6[Resource Group Manager]
    end
    
    SP1 -->|Uses| BR1
    SP2 -->|Uses| R1
    SP3 -->|Uses| R2
    SP4 -->|Uses| BR2
    SP4 -->|Uses| BR3
    SP5 -->|Uses| R3
    SP6 -->|Uses| BR3
```

## Security Storage
```mermaid
graph TD
    subgraph "Local Machine"
        SF[Secrets File<br/>.config/azure-setup]
        SPF[Service Principal File<br/>.config/azure-setup]
    end
    
    subgraph "GitHub Repository"
        GS[GitHub Secrets]
        WF[GitHub Workflows]
    end
    
    SF -->|Stores| AdminCreds[Administrator Credentials]
    SF -->|Stores| SPCreds[Service Principal Credentials]
    SPF -->|Stores| SPMeta[Service Principal Metadata]
    SPCreds -->|Subset Copied To| GS
    GS -->|Used By| WF
```