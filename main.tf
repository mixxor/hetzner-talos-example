module "cluster" {
  source       = "github.com/mixxor/hetzner-talos?ref=0.0.2-alpha"
  hcloud_token = var.hcloud_token

  cluster_name       = var.cluster_name
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
  talos_extensions   = var.talos_extensions

  control_plane_count       = var.control_plane_count
  control_plane_server_type = var.control_plane_server_type
  control_plane_locations   = var.control_plane_locations
  worker_nodepools          = var.worker_nodepools

  location     = var.location
  network_zone = var.network_zone

  # VPN clients can reach K8s/Talos APIs
  firewall_allow_cidrs = var.enable_vpn ? [var.wireguard_vpn_cidr] : []

  enable_csi        = var.enable_csi
  delete_protection = var.delete_protection

  cilium_version         = var.cilium_version
  hcloud_ccm_version     = var.hcloud_ccm_version
  hcloud_csi_version     = var.hcloud_csi_version
  metrics_server_version = var.metrics_server_version
}
