terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    null = {
      source = "hashicorp/null"
    }
  }
}

// variable declarations
variable "name" {
  type = string
}
variable "owner_email" {
  type = string
}
variable "tenant_id" {
  sensitive = true
}
variable "subscription_id" {
  sensitive = true
}
variable "k8s_version" {
  type = string
}
variable "node_count" {
  type    = number
  default = 1
}
variable "node_vm_type" {
  type    = string
  default = "Standard_B2s"
}
variable "gpu_node_vm_type" {
  type    = string
  default = "standard_nv6ads_a10_v5"
}
variable "node_os" {
  type    = string
  default = "Ubuntu"
}
variable "node_disk_size_gb" {
  type    = number
  default = 100
}
variable "location" {}
variable "address_space" {
  type    = string
  default = "10.0.0.0/16"
}

// azure provider declaration
provider "azurerm" {
  features {}
}

// create azure resource group to isolate resources
resource "azurerm_resource_group" "primary" {
  name     = "${var.name}-rg"
  location = var.location
  tags = {
    Owner = "${var.owner_email}"
  }
}

// create virtual network for k8s to reside in
resource "azurerm_virtual_network" "cluster-network" {
  name                = "${var.name}-vnet"
  location            = var.location
  address_space       = [var.address_space]
  resource_group_name = azurerm_resource_group.primary.name
  tags = {
    Owner = "${var.owner_email}"
  }
  subnet {
    name           = "subnet"
    address_prefix = "10.0.1.0/24"
  }
}

resource "azurerm_kubernetes_cluster" "primary" {
  name                = "${var.name}-cluster"
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name
  kubernetes_version  = var.k8s_version
  dns_prefix          = "${var.name}-dns"
  default_node_pool {
    name            = "default"
    node_count      = var.node_count
    os_sku          = var.node_os
    os_disk_size_gb = var.node_disk_size_gb
    # Required to attach multiple node pools
    type    = "VirtualMachineScaleSets"
    vm_size = var.node_vm_type
  }
  identity {
    type = "SystemAssigned"
  }
  tags = {
    Owner = "${var.owner_email}"
  }
  lifecycle {
    ignore_changes = [api_server_authorized_ip_ranges]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "gpu" {
  name                  = "gpu"
  node_count            = var.node_count
  kubernetes_cluster_id = azurerm_kubernetes_cluster.primary.id
  os_sku                = var.node_os
  os_disk_size_gb       = var.node_disk_size_gb
  vm_size               = var.gpu_node_vm_type
  node_labels = {
    # "kubernetes.azure.com/mode"      = "system"
    # "kubernetes.azure.com/agentpool" = "gpu"
  }
  node_taints = ["sku=gpu:NoSchedule"]
  tags = {
    Owner = "${var.owner_email}"
  }
}

output "host" {
  value     = azurerm_kubernetes_cluster.primary.kube_config[0].host
  sensitive = true
}

output "username" {
  value     = azurerm_kubernetes_cluster.primary.kube_config[0].username
  sensitive = true
}

output "password" {
  value     = azurerm_kubernetes_cluster.primary.kube_config[0].password
  sensitive = true
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.primary.kube_config[0].client_certificate
  sensitive = true
}

output "client_key" {
  value     = azurerm_kubernetes_cluster.primary.kube_config[0].client_key
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = azurerm_kubernetes_cluster.primary.kube_config[0].cluster_ca_certificate
  sensitive = true
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.primary.kube_config_raw

  sensitive = true
}
