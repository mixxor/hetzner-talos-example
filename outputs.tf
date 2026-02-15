# --- Module passthrough ---

output "kubeconfig" {
  description = "Kubeconfig for kubectl access (uses private LB IP)"
  value       = module.cluster.kubeconfig
  sensitive   = true
}

output "kubeconfig_public" {
  description = "Kubeconfig using public CP IP (direct access)"
  value       = module.cluster.kubeconfig_public
  sensitive   = true
}

output "kubeconfig_tunnel" {
  description = "Kubeconfig via SSH tunnel (use with: ./deploy.sh tunnel)"
  value = var.enable_vpn ? replace(
    module.cluster.kubeconfig,
    "https://${module.cluster.k8s_api_lb_ip}:6443",
    "https://127.0.0.1:16443"
  ) : null
  sensitive = true
}

output "talosconfig" {
  description = "Talosconfig for talosctl access"
  value       = module.cluster.talosconfig
  sensitive   = true
}

output "control_plane_ips" {
  description = "Public IPs of control plane nodes"
  value       = module.cluster.control_plane_ips
}

output "control_plane_private_ips" {
  description = "Private IPs of control plane nodes"
  value       = module.cluster.control_plane_private_ips
}

output "k8s_api_lb_ip" {
  description = "Private IP of the Kubernetes API load balancer"
  value       = module.cluster.k8s_api_lb_ip
}

output "connection_info" {
  description = "Connection information for the cluster"
  value       = module.cluster.connection_info
}

output "cluster_summary" {
  description = "Summary of deployed resources"
  value       = module.cluster.cluster_summary
}

# --- VPN outputs ---

output "vpn_ssh_private_key" {
  description = "SSH private key to access VPN gateway"
  value       = try(tls_private_key.vpn.private_key_openssh, null)
  sensitive   = true
}

output "vpn_gateway_public_ip" {
  description = "Public IP of the VPN gateway"
  value       = try(hcloud_server.vpn_gateway.ipv4_address, null)
}

output "vpn_gateway_private_ip" {
  description = "Private IP of the VPN gateway"
  value       = try(hcloud_server_network.vpn_gateway.ip, null)
}

output "wireguard_client_config" {
  description = "Instructions to get WireGuard client config from VPN gateway"
  value = try(join("\n", [
    "ssh -i /tmp/vpn-key root@${hcloud_server.vpn_gateway.ipv4_address} 'cat /etc/wireguard/client.conf' > ~/wg-hetzner.conf",
    "sudo wg-quick up ~/wg-hetzner.conf",
  ]), "VPN disabled. Set enable_vpn = true to deploy.")
}
