terraform {
  required_providers {
    grid = {
      source = "threefoldtech/grid"
    }
  }
}

# Variables
variable "mnemonic" {
  type = string
  sensitive = true
  description = "ThreeFold mnemonic for authentication"
}
variable "SSH_KEY" { 
  type = string
  default = null
  description = "SSH public key content (if null, will use ~/.ssh/id_ed25519.pub)"
}
variable "control_nodes" { type = list(number) }  # e.g. [6905, 6906, 6907]
variable "worker_nodes" { type = list(number) }   # e.g. [6910, 6911, 6912]
variable "control_cpu" { type = number }
variable "control_mem" { type = number }
variable "control_disk" { type = number }
variable "worker_cpu" { type = number }
variable "worker_mem" { type = number }
variable "worker_disk" { type = number }

provider "grid" {
  mnemonic = var.mnemonic
  network  = "main"
}

# Generate unique mycelium keys/seeds for all nodes
locals {
  all_nodes = concat(var.control_nodes, var.worker_nodes)
}

resource "random_bytes" "k3s_mycelium_key" {
  for_each = toset([for n in local.all_nodes : tostring(n)])  # Convert numbers to strings
  length   = 32
}

resource "random_bytes" "k3s_ip_seed" {
  for_each = toset([for n in local.all_nodes : tostring(n)])  # Convert numbers to strings
  length   = 6
}

# Mycelium overlay network
resource "grid_network" "k3s_network" {
  name        = "k3s_cluster_network"
  nodes       = local.all_nodes
  ip_range    = "10.1.0.0/16"
  add_wg_access = true
  mycelium_keys = {
    for node in local.all_nodes : tostring(node) => random_bytes.k3s_mycelium_key[tostring(node)].hex
  }
}

# Unified node deployment
resource "grid_deployment" "k3s_nodes" {
  for_each = {
    for idx, node in local.all_nodes : 
    "node_${idx}" => {
      node_id    = node
      is_control = contains(var.control_nodes, node)
    }
  }

  node         = each.value.node_id
  network_name = grid_network.k3s_network.name

  disks {
    name = "disk_${each.key}"
    size = each.value.is_control ? var.control_disk : var.worker_disk
  }

  vms {
    name       = "vm_${each.key}"
    flist      = "https://hub.grid.tf/tf-official-vms/ubuntu-24.04-full.flist"
    cpu        = each.value.is_control ? var.control_cpu : var.worker_cpu
    memory     = each.value.is_control ? var.control_mem : var.worker_mem
    entrypoint = "/sbin/zinit init"
    publicip   = !each.value.is_control  # Workers get public IPs
    mycelium_ip_seed = random_bytes.k3s_ip_seed[tostring(each.value.node_id)].hex  # Convert to string

    env_vars = {
      SSH_KEY = var.SSH_KEY != null ? var.SSH_KEY : (
        fileexists(pathexpand("~/.ssh/id_ed25519.pub")) ? 
          file(pathexpand("~/.ssh/id_ed25519.pub")) : 
          file(pathexpand("~/.ssh/id_rsa.pub"))
      )
    }

    mounts {
      name        = "disk_${each.key}"
      mount_point = "/data"
    }
    rootfs_size = 20480
  }
}

# Outputs (remain the same as previous version)
output "wireguard_ips" {
  value = {
    for key, dep in grid_deployment.k3s_nodes : 
    key => dep.vms[0].ip
  }
}

output "mycelium_ips" {
  value = {
    for key, dep in grid_deployment.k3s_nodes : 
    key => dep.vms[0].mycelium_ip
  }
}

output "worker_public_ips" {
  value = {
    for key, dep in grid_deployment.k3s_nodes : 
    key => dep.vms[0].computedip if contains(var.worker_nodes, dep.node)
  }
}

output "wg_config" {
  value = grid_network.k3s_network.access_wg_config
}