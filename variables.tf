variable "hcloud_token" {
  description = "Hetzner Cloud API token - set via TF_VAR_hcloud_token env var"
  type        = string
  sensitive   = true
}

# --- Cluster config (passthrough to module) ---

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "talos-k8s"
}

variable "talos_version" {
  description = "Talos Linux version"
  type        = string
  default     = "v1.12.4"
}

variable "talos_extensions" {
  description = "Talos system extensions to include"
  type        = list(string)
  default     = ["siderolabs/qemu-guest-agent", "siderolabs/iscsi-tools", "siderolabs/util-linux-tools"]
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.35.0"
}

variable "control_plane_count" {
  description = "Number of control plane nodes (must be odd)"
  type        = number
  default     = 3
}

variable "control_plane_server_type" {
  description = "Hetzner server type for control plane nodes"
  type        = string
  default     = "cx33"
}

variable "control_plane_locations" {
  description = "Locations for control plane nodes"
  type        = list(string)
  default     = ["fsn1", "nbg1", "hel1"]
}

variable "worker_nodepools" {
  description = "Worker node pools"
  type = list(object({
    name        = string
    count       = number
    server_type = string
    locations   = list(string)
    labels      = optional(map(string), {})
    taints      = optional(list(string), [])
  }))
  default = [{
    name        = "default"
    count       = 3
    server_type = "cx33"
    locations   = ["fsn1", "nbg1", "hel1"]
  }]
}

variable "location" {
  description = "Primary Hetzner datacenter location"
  type        = string
  default     = "fsn1"
}

variable "network_zone" {
  description = "Hetzner network zone"
  type        = string
  default     = "eu-central"
}

variable "enable_csi" {
  description = "Install Hetzner CSI driver"
  type        = bool
  default     = true
}

variable "delete_protection" {
  description = "Enable Hetzner delete/rebuild protection"
  type        = bool
  default     = false
}

variable "cilium_version" {
  description = "Cilium Helm chart version"
  type        = string
  default     = "1.19.0"
}

variable "hcloud_ccm_version" {
  description = "Hetzner Cloud Controller Manager version"
  type        = string
  default     = "1.30.0"
}

variable "hcloud_csi_version" {
  description = "Hetzner CSI driver Helm chart version"
  type        = string
  default     = "2.19.0"
}

variable "metrics_server_version" {
  description = "Metrics Server Helm chart version"
  type        = string
  default     = "3.13.0"
}

# --- ArgoCD ---

variable "enable_argocd" {
  description = "Install ArgoCD"
  type        = bool
  default     = true
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "9.4.2"
}

# --- Etcd backup ---

variable "enable_etcd_backup" {
  description = "Enable periodic etcd backups to S3-compatible storage via Kubernetes CronJob"
  type        = bool
  default     = false
}

variable "etcd_backup_s3_endpoint" {
  description = "S3-compatible endpoint for etcd backups"
  type        = string
  default     = ""
}

variable "etcd_backup_s3_bucket" {
  description = "S3 bucket name for etcd backups"
  type        = string
  default     = ""
}

variable "etcd_backup_s3_access_key" {
  description = "S3 access key for etcd backups"
  type        = string
  sensitive   = true
  default     = ""
}

variable "etcd_backup_s3_secret_key" {
  description = "S3 secret key for etcd backups"
  type        = string
  sensitive   = true
  default     = ""
}

variable "etcd_backup_schedule" {
  description = "Cron schedule for etcd backups"
  type        = string
  default     = "0 */6 * * *"
}

variable "etcd_backup_retention" {
  description = "Number of etcd backup snapshots to retain"
  type        = number
  default     = 10
}

# --- VPN config ---

variable "enable_vpn" {
  description = "Deploy WireGuard VPN gateway for secure private access"
  type        = bool
  default     = true
}

variable "vpn_server_type" {
  description = "Hetzner server type for VPN gateway"
  type        = string
  default     = "cx33"
}

variable "vpn_subnet_cidr" {
  description = "VPN gateway subnet CIDR"
  type        = string
  default     = "10.0.0.0/24"
}

variable "wireguard_port" {
  description = "WireGuard listen port"
  type        = number
  default     = 51820

  validation {
    condition     = var.wireguard_port >= 1024 && var.wireguard_port <= 65535
    error_message = "WireGuard port must be between 1024 and 65535."
  }
}

variable "wireguard_vpn_cidr" {
  description = "WireGuard VPN tunnel CIDR"
  type        = string
  default     = "10.100.0.0/24"
}

variable "wireguard_client_ip" {
  description = "WireGuard client IP address"
  type        = string
  default     = "10.100.0.2"
}

variable "network_cidr" {
  description = "Main network CIDR"
  type        = string
  default     = "10.0.0.0/8"
}
