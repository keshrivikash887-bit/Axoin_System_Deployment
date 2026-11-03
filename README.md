# Axoin System Deployment - Azure Infrastructure as Code (Terraform)

An enterprise-grade, modular Infrastructure as Code (IaC) project using **Terraform** and the **AzureRM Provider** to automate the provisioning of a secure, multi-tier cloud environment in **Microsoft Azure**.

---

## Table of Contents

- [Overview](#overview)
- [Architecture & Design](#architecture--design)
- [Repository Structure](#repository-structure)
- [Modules Breakdown](#modules-breakdown)
  - [1. Resource Group Module](#1-resource-group-module)
  - [2. Virtual Network Module](#2-virtual-network-module)
  - [3. Subnet Module](#3-subnet-module)
  - [4. Public IP Module](#4-public-ip-module)
  - [5. Network Security Group (NSG) Module](#5-network-security-group-nsg-module)
  - [6. Virtual Machine Module](#6-virtual-machine-module)
  - [7. Azure Bastion Module](#7-azure-bastion-module)
- [Environment Configuration (`preprod`)](#environment-configuration-preprod)
  - [Remote State Management](#remote-state-management)
  - [Dependency Graph & Orchestration](#dependency-graph--orchestration)
  - [Security Rules & Port Configuration](#security-rules--port-configuration)
  - [Key Vault & Secret Management](#key-vault--secret-management)
- [Prerequisites](#prerequisites)
- [Deployment Guide](#deployment-guide)
- [Configuration Reference (`terraform.tfvars`)](#configuration-reference-terraformtfvars)
- [Best Practices & Security Notes](#best-practices--security-notes)

---

## Overview

This repository deploys a complete 3-tier application infrastructure (Frontend, Backend, and Database) along with dedicated administrative access via Azure Bastion. The codebase is organized into reusable child modules under `Module/` and an environment layer under `environment/preprod/`, ensuring high reusability, maintainability, and clean separation of concerns.

### Key Highlights:
- **Modular IaC**: Child modules designed with `for_each` loops to handle multiple resource instances dynamically.
- **Multi-Tier Network Topology**: Segmented subnets for Frontend, Backend, Database tiers, plus a dedicated subnet for Azure Bastion.
- **Tiered Security**: Granular Network Security Groups (NSGs) using dynamic security rule blocks.
- **Secure VM Access**: Passwords sourced dynamically from **Azure Key Vault** to avoid exposing plaintext secrets in code or version control.
- **Azure Bastion Integration**: Secure, seamless RDP/SSH connectivity directly via the Azure Portal without exposing public management ports.
- **Remote State**: Backed by an Azure Storage Account container with state locking for reliable team collaboration.

---

## Architecture & Design

```
+------------------------------------------------------------------------------------------+
| Azure Subscription                                                                       |
| Resource Group: Axoin_system12 (Region: South Africa North)                              |
|                                                                                          |
|  +------------------------------------------------------------------------------------+  |
|  | Virtual Network: Axoin_system12_vnet (10.0.0.0/16)                                 |  |
|  |                                                                                    |  |
|  |  +-----------------------------+       +-----------------------------+             |  |
|  |  | Frontend Subnet             |       | Backend Subnet              |             |  |
|  |  | (10.0.1.0/24)               |       | (10.0.2.0/24)               |             |  |
|  |  |  - Axion-frontend-vm        |       |  - Axion-backend-vm         |             |  |
|  |  |  - frontend_nic             |       |  - backend_nic              |             |  |
|  |  |  - frontend_pip (Public IP) |       |  - NSG: backend_nsg         |             |  |
|  |  |  - NSG: frontend_nsg        |       +-----------------------------+             |  |
|  |  +-----------------------------+                                                   |  |
|  |                                                                                    |  |
|  |  +-----------------------------+       +-----------------------------+             |  |
|  |  | Database Subnet             |       | AzureBastionSubnet          |             |  |
|  |  | (10.0.3.0/24)               |       | (10.0.4.0/24)               |             |  |
|  |  |  - Axion-database-vm        |       |  - Azure Bastion Host       |             |  |
|  |  |  - database_nic             |       |  - bastion_pip (Public IP)  |             |  |
|  |  |  - NSG: database_nsg        |       +-----------------------------+             |  |
|  |  +-----------------------------+                                                   |  |
|  +------------------------------------------------------------------------------------+  |
|                                                                                          |
|  +-----------------------------+                                                         |
|  | Azure Key Vault             |  ---> Injects admin password into Linux VMs at runtime  |
|  | (rahul-vault12)             |                                                         |
|  +-----------------------------+                                                         |
+------------------------------------------------------------------------------------------+
```

---

## Repository Structure

```text
Axoin_System_Deployment/
├── .gitignore                                 # Git ignore file for Terraform states, vars, and logs
├── README.md                                  # Project documentation
│
├── environment/                               # Environment configurations
│   └── preprod/
│       ├── main.tf                            # Root orchestration calling child modules with dependencies
│       ├── provider.tf                        # AzureRM provider (v5.2.0) & remote backend config
│       ├── variable.tf                        # Variable schema and typed definitions
│       └── terraform.tfvars                   # Pre-production environment parameter values
│
└── Module/                                    # Reusable infrastructure modules
    ├── azurerm_bastion/                       # Azure Bastion module
    │   ├── data.tf                            # Subnet and Public IP data lookups
    │   ├── main.tf                            # azurerm_bastion_host resource
    │   └── variable.tf                        # Module input variables
    │
    ├── Azurerm_nsg/                           # Network Security Group module
    │   ├── main.tf                            # azurerm_network_security_group with dynamic rules
    │   └── variable.tf                        # NSG and security rules variable schemas
    │
    ├── Azurerm_public_ip/                     # Public IP module
    │   ├── main.tf                            # azurerm_public_ip resource
    │   └── variable.tf                        # Public IP variable schema
    │
    ├── Azurerm_resource_group/                # Resource Group module
    │   ├── main.tf                            # azurerm_resource_group resource
    │   └── variable.tf                        # Resource Group variable schema
    │
    ├── Azurerm_subnet/                        # Subnet module
    │   ├── main.tf                            # azurerm_subnet resource
    │   └── variable.tf                        # Subnet variable schema
    │
    ├── Azurerm_virtual_machine/               # Virtual Machine module
    │   ├── data.tf                            # Subnet, Public IP, NSG, and Key Vault lookups
    │   ├── main.tf                            # NIC, NIC-NSG association, and Linux VM resources
    │   └── variable.tf                        # VM configuration variable schema
    │
    └── Azurerm_virtual_network/               # Virtual Network module
        ├── main.tf                            # azurerm_virtual_network resource
        └── variable.tf                        # VNet variable schema
```

---

## Modules Breakdown

### 1. Resource Group Module
**Path:** `Module/Azurerm_resource_group`
- **Purpose:** Creates Azure Resource Groups as the foundational lifecycle container for resources.
- **Logic:** Uses `for_each = var.rg_names` to provision one or multiple resource groups dynamically across regions.
- **Inputs:** `rg_names` map containing `name` and `location`.

### 2. Virtual Network Module
**Path:** `Module/Azurerm_virtual_network`
- **Purpose:** Deploys software-defined Virtual Networks (VNets) in Azure.
- **Logic:** Iterates over `var.vnet_name` map specifying `address_space`, `location`, and target resource group.
- **Inputs:** `vnet_name` map.

### 3. Subnet Module
**Path:** `Module/Azurerm_subnet`
- **Purpose:** Segments the Virtual Network address space into dedicated subnets.
- **Logic:** Provisions subnets bound to a parent VNet using `for_each = var.subnet_name`.
- **Inputs:** `subnet_name` map defining subnet names, CIDR prefixes (`address_prefixes`), and parent VNet.

### 4. Public IP Module
**Path:** `Module/Azurerm_public_ip`
- **Purpose:** Provisions Static Standard SKU Public IPs for external network ingress (e.g., Frontend and Bastion host).
- **Logic:** Uses `for_each = var.public_ip` with `Static` allocation and `Standard` SKU.
- **Inputs:** `public_ip` map.

### 5. Network Security Group (NSG) Module
**Path:** `Module/Azurerm_nsg`
- **Purpose:** Implements stateful network packet filtering across subnets and VMs.
- **Logic:** Employs a `dynamic "security_rule"` block to iterate over a list of rule definitions (ports, protocols, direction, access, priority) per NSG.
- **Inputs:** `nsg_name` map containing nested security rule definitions.

### 6. Virtual Machine Module
**Path:** `Module/Azurerm_virtual_machine`
- **Purpose:** Deploys Linux Virtual Machines with attached Network Interfaces and NSG associations.
- **Logic:**
  - Queries existing subnets, public IPs, and NSGs via `data` sources.
  - Retrieves admin credentials securely from an **Azure Key Vault** (`rahul-vault12`) secret (`password`).
  - Creates the Network Interface (`azurerm_network_interface`) with dynamic private IP allocation.
  - Links NICs to corresponding NSGs via `azurerm_network_interface_security_group_association`.
  - Deploys Ubuntu 22.04 LTS Gen2 virtual machines (`azurerm_linux_virtual_machine`) with standard OS disk settings (`ReadWrite` caching, `Standard_LRS`).
- **Inputs:** `vms` map.

### 7. Azure Bastion Module
**Path:** `Module/azurerm_bastion`
- **Purpose:** Provides fully managed PaaS-based RDP/SSH connectivity without exposing VMs to public IPs or open internet ports.
- **Logic:** Fetches the mandatory `AzureBastionSubnet` and dedicated public IP via `data` blocks, and attaches them to `azurerm_bastion_host`.
- **Inputs:** `bastions` map.

---

## Environment Configuration (`preprod`)

### Remote State Management
The project utilizes Azure Blob Storage for state locking and remote state persistence in `environment/preprod/provider.tf`:

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.2.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "kuldeep_rg"
    storage_account_name = "lalakastorage"
    container_name       = "pappu"
    key                  = "kuldeep.tfstate"
  }
}
```

### Dependency Graph & Orchestration
In `environment/preprod/main.tf`, module execution order is strictly guaranteed using `depends_on`:
1. **`module.rg`**: Resource Groups created first.
2. **`module.vnet`** & **`module.public_ip`**: Depend on `module.rg`.
3. **`module.subnet`**: Depends on `module.rg` and `module.vnet`.
4. **`module.nsg`**: Depends on `module.rg` and `module.subnet`.
5. **`module.vm`**: Depends on `module.subnet` and `module.nsg`.
6. **`module.bastion`**: Depends on `module.rg`, `module.subnet`, and `module.public_ip`.

### Security Rules & Port Configuration
Each tier is protected by a dedicated NSG with predefined inbound rules:
| Rule Name | Priority | Direction | Access | Protocol | Port Range | Description |
|:---|:---:|:---:|:---:|:---:|:---:|:---|
| `Allow-SSH` | 100 | Inbound | Allow | TCP | `22` | Secure remote shell access |
| `Allow-HTTP` | 110 | Inbound | Allow | TCP | `80` | Web traffic ingress |
| `Allow-HTTPS`| 120 | Inbound | Allow | TCP | `443`| Secure SSL/TLS web traffic |

### Key Vault & Secret Management
To adhere to security best practices and prevent credentials from leaking into source code:
- Admin password authentication is enabled (`disable_password_authentication = false`).
- Instead of hardcoding credentials in the VM resource, `Module/Azurerm_virtual_machine/data.tf` reads the secret `password` directly from Key Vault `rahul-vault12`.

---

## Prerequisites

Before running this Terraform deployment, ensure you have:
1. **Azure CLI** installed: [Install Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
2. **Terraform CLI** installed (`v1.5+` recommended): [Install Terraform](https://developer.hashicorp.com/terraform/install)
3. Authenticated session to Azure:
   ```bash
   az login
   az account set --subscription "<YOUR_SUBSCRIPTION_ID>"
   ```
4. Pre-existing Azure resources for state storage and secrets:
   - Resource Group: `kuldeep_rg`
   - Storage Account: `lalakastorage` with blob container: `pappu`
   - Azure Key Vault: `rahul-vault12` containing secret `password`

---

## Deployment Guide

Follow these steps to deploy the pre-production environment:

### Step 1: Navigate to the Environment Directory
```bash
cd environment/preprod
```

### Step 2: Initialize Terraform
Initialize the backend and download the required provider plugins:
```bash
terraform init
```

### Step 3: Validate the Configuration
Verify syntax and module arguments:
```bash
terraform validate
```

### Step 4: Preview the Execution Plan
Review all resources scheduled for creation:
```bash
terraform plan -out=tfplan
```

### Step 5: Apply the Configuration
Provision the infrastructure:
```bash
terraform apply tfplan
```

### Step 6: Destroy / Clean Up (Optional)
When the infrastructure is no longer needed:
```bash
terraform destroy
```

---

## Configuration Reference (`terraform.tfvars`)

Summary of values configured in `environment/preprod/terraform.tfvars`:

| Resource Type | Resource Name / Key | Details / CIDR / Size | Region |
|:---|:---|:---|:---|
| **Resource Group** | `Axoin_system12` | Main environment RG | South Africa North |
| **Resource Group** | `Axoin_system123` | Secondary RG | East US |
| **Virtual Network** | `Axoin_system12_vnet` | `10.0.0.0/16` | South Africa North |
| **Subnet** | `Axoin_system12_frontend_subnet` | `10.0.1.0/24` | South Africa North |
| **Subnet** | `Axoin_system12_backend_subnet` | `10.0.2.0/24` | South Africa North |
| **Subnet** | `Axoin_system12_database_subnet` | `10.0.3.0/24` | South Africa North |
| **Subnet** | `AzureBastionSubnet` | `10.0.4.0/24` (Mandatory name for Bastion) | South Africa North |
| **Public IP** | `frontend_pip` | Static, Standard SKU | South Africa North |
| **Network Security Group**| `frontend_nsg` | Inbound: 22, 80, 443 | South Africa North |
| **Network Security Group**| `backend_nsg` | Inbound: 22, 80, 443 | South Africa North |
| **Network Security Group**| `database_nsg` | Inbound: 22, 80, 443 | South Africa North |
| **Virtual Machine** | `Axion-frontend-vm` | `Standard_DS1_v2`, Ubuntu 22.04 LTS | South Africa North |
| **Virtual Machine** | `Axion-backend-vm` | `Standard_DS1_v2`, Ubuntu 22.04 LTS | South Africa North |
| **Virtual Machine** | `Axion-database-vm` | `Standard_DS1_v2`, Ubuntu 22.04 LTS | South Africa North |
| **Azure Bastion** | `bastion1` | PaaS Bastion Host on `AzureBastionSubnet` | South Africa North |

---

## Best Practices & Security Notes

1. **Secrets Security**:
   - `*.tfvars` files are excluded in `.gitignore` to prevent secret leakage.
   - Admin credentials for VMs are fetched dynamically from Azure Key Vault via Terraform data sources.
2. **Bastion Host Access**:
   - For enhanced security, backend and database VMs should not have direct public IPs. Management access is handled through Azure Bastion.
3. **Module Isolation**:
   - Each infrastructure component is encapsulated in its own module under `Module/`, allowing independent updates, unit testing, and reuse across multiple environments (e.g., `dev`, `stage`, `prod`).
4. **State Integrity**:
   - State locking via Azure Storage backend prevents concurrent modifications and state file corruption during team deployments.
