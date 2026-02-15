# WireGuard VPN gateway for secure private access to the cluster.

resource "tls_private_key" "vpn" {
  algorithm = "ED25519"

  lifecycle {
    enabled = var.enable_vpn
  }
}

resource "hcloud_ssh_key" "vpn" {
  name       = "${var.cluster_name}-vpn"
  public_key = tls_private_key.vpn.public_key_openssh

  lifecycle {
    enabled = var.enable_vpn
  }
}

resource "hcloud_network_subnet" "vpn" {
  network_id   = module.cluster.network_id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = var.vpn_subnet_cidr

  lifecycle {
    enabled = var.enable_vpn
  }
}

resource "hcloud_firewall" "vpn_gateway" {
  name = "${var.cluster_name}-vpn-gateway"

  rule {
    direction  = "in"
    protocol   = "udp"
    port       = tostring(var.wireguard_port)
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = module.cluster.firewall_allowed_cidrs
  }

  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  lifecycle {
    enabled = var.enable_vpn
  }
}

resource "hcloud_server" "vpn_gateway" {
  name        = "${var.cluster_name}-vpn"
  server_type = var.vpn_server_type
  image       = "ubuntu-24.04"
  location    = var.location

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  ssh_keys     = [hcloud_ssh_key.vpn.id]
  firewall_ids = [hcloud_firewall.vpn_gateway.id]

  user_data = templatefile("${path.module}/files/wireguard-setup.sh.tftpl", {
    wireguard_port      = var.wireguard_port
    wireguard_server_ip = "10.100.0.1"
    wireguard_cidr      = var.wireguard_vpn_cidr
    client_ip           = var.wireguard_client_ip
    private_network     = var.network_cidr
    vpn_private_ip      = "10.0.0.2"
    kubernetes_version  = var.kubernetes_version
    talos_version       = var.talos_version
  })

  labels = {
    role    = "vpn-gateway"
    cluster = var.cluster_name
  }

  depends_on = [hcloud_network_subnet.vpn]

  lifecycle {
    enabled = var.enable_vpn
  }
}

resource "hcloud_server_network" "vpn_gateway" {
  server_id  = hcloud_server.vpn_gateway.id
  network_id = module.cluster.network_id
  ip         = "10.0.0.2"

  lifecycle {
    enabled = var.enable_vpn
  }
}
