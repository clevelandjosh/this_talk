locals {
  # Your specified network: 10.209.96.0/19 (8,192 IPs)
  # This provides excellent space for hub and spoke topology
  
  address_bits = tonumber(split("/", var.vnet_address_space)[1])
  
  # For /19 network, allocate as follows:
  # Hub: /22 (1,024 IPs) - 10.209.96.0/22
  # MCP Spoke: /23 (512 IPs) - 10.209.100.0/23  
  # AKS Spoke: /22 (1,024 IPs) - 10.209.104.0/22
  # VM Spoke: /23 (512 IPs) - 10.209.108.0/23
  # AI Spoke: /22 (1,024 IPs) - 10.209.112.0/22
  
  # Calculate VNet address spaces optimized for 10.209.96.0/19
  hub_address_space   = cidrsubnet(var.vnet_address_space, 3, 0)  # 10.209.96.0/22
  mcp_spoke_cidr     = cidrsubnet(var.vnet_address_space, 4, 8)  # 10.209.100.0/23
  aks_spoke_cidr     = cidrsubnet(var.vnet_address_space, 3, 2)  # 10.209.104.0/22  
  vm_spoke_cidr      = cidrsubnet(var.vnet_address_space, 4, 12) # 10.209.108.0/23
  ai_spoke_cidr      = cidrsubnet(var.vnet_address_space, 3, 4)  # 10.209.112.0/22
  
  # Hub subnets (within 10.209.96.0/22)
  hub_firewall_subnet = cidrsubnet(local.hub_address_space, 4, 0)   # 10.209.96.0/26 (64 IPs)
  hub_bastion_subnet  = cidrsubnet(local.hub_address_space, 5, 2)   # 10.209.96.64/27 (32 IPs)
  hub_gateway_subnet  = cidrsubnet(local.hub_address_space, 5, 3)   # 10.209.96.96/27 (32 IPs)
  hub_services_subnet = cidrsubnet(local.hub_address_space, 2, 1)   # 10.209.97.0/24 (256 IPs)
  
  # MCP spoke subnets (within 10.209.100.0/23)
  mcp_servers_subnet = cidrsubnet(local.mcp_spoke_cidr, 2, 0)       # 10.209.100.0/25 (128 IPs)
  mcp_lb_subnet      = cidrsubnet(local.mcp_spoke_cidr, 3, 2)       # 10.209.100.128/26 (64 IPs)
  
  # AKS spoke subnets (within 10.209.104.0/22)
  aks_nodes_subnet   = cidrsubnet(local.aks_spoke_cidr, 1, 0)       # 10.209.104.0/23 (512 IPs)
  aks_pods_subnet    = cidrsubnet(local.aks_spoke_cidr, 1, 1)       # 10.209.106.0/23 (512 IPs)
  
  # VM spoke subnets (within 10.209.108.0/23)
  vm_apps_subnet     = cidrsubnet(local.vm_spoke_cidr, 2, 0)        # 10.209.108.0/25 (128 IPs)
  vm_mgmt_subnet     = cidrsubnet(local.vm_spoke_cidr, 3, 2)        # 10.209.108.128/26 (64 IPs)
  
  # AI spoke subnets (within 10.209.112.0/22)
  ai_services_subnet = cidrsubnet(local.ai_spoke_cidr, 2, 0)        # 10.209.112.0/24 (256 IPs)
  ai_compute_subnet  = cidrsubnet(local.ai_spoke_cidr, 2, 1)        # 10.209.113.0/24 (256 IPs)
  
  # Common tags following Azure best practices
  common_tags = merge(var.tags, {
    Environment   = "demo"
    Project      = "iss-security-automation"
    ManagedBy    = "terraform"
    NetworkTier  = "hub-spoke"
    AddressSpace = var.vnet_address_space
  })
}