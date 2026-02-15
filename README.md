# Hetzner Talos Example

Example root module that deploys a Talos Kubernetes cluster on
Hetzner Cloud using the
[hetzner-talos](https://github.com/mixxor/hetzner-talos) module,
with optional WireGuard VPN, ArgoCD, and etcd backups.

## Architecture

![Architecture](https://raw.githubusercontent.com/mixxor/hetzner-talos/main/docs/architecture.svg)

## Quick Start

```bash
cp terraform.tfvars.example terraform.tfvars  # adjust as needed
cp .env.example .env                          # set your token
./deploy.sh deploy
```

This will:
1. Deploy the Kubernetes cluster via the `hetzner-talos` module
2. Install ArgoCD (if `enable_argocd = true`)
3. Deploy a WireGuard VPN gateway (if `enable_vpn = true`)
4. Connect you to the VPN
5. Write kubeconfig to `~/.kube/hetzner`

## Manual Deploy

```bash
export TF_VAR_hcloud_token="your-token"
tofu init && tofu apply

# Get VPN config
tofu output -raw vpn_ssh_private_key > /tmp/vpn-key && chmod 600 /tmp/vpn-key
ssh -i /tmp/vpn-key root@$(tofu output -raw vpn_gateway_public_ip) \
  'cat /etc/wireguard/client.conf' > ~/wg-hetzner.conf
sudo wg-quick up ~/wg-hetzner.conf

# Get kubeconfig
tofu output -raw kubeconfig_public > ~/.kube/hetzner
export KUBECONFIG=~/.kube/hetzner
kubectl get nodes
```

## Without VPN

Set `enable_vpn = false` in `terraform.tfvars`. The cluster stays
accessible via public CP IPs, firewalled to your IP.

## SSH Tunnel (alternative to full VPN)

```bash
./deploy.sh tunnel    # forwards localhost:16443 -> API LB
```

## Commands

| Command | Description |
|---------|-------------|
| `./deploy.sh deploy` | Deploy infrastructure + connect VPN |
| `./deploy.sh destroy` | Destroy all infrastructure |
| `./deploy.sh tunnel` | SSH tunnel to K8s API |
| `./deploy.sh vpn-up` | Connect to WireGuard VPN |
| `./deploy.sh vpn-down` | Disconnect from WireGuard VPN |

## Module Source

By default this uses a relative path (`../hetzner-talos`). For
production, change the source to a versioned reference:

```hcl
module "cluster" {
  source = "github.com/mixxor/hetzner-talos?ref=v1.0.0"
  # ...
}
```

## Prerequisites

- [OpenTofu](https://opentofu.org/docs/intro/install/) >= 1.5
- [hcloud CLI](https://github.com/hetznercloud/cli)
- [Helm](https://helm.sh/docs/intro/install/)
- [jq](https://jqlang.github.io/jq/)
- [WireGuard](https://www.wireguard.com/install/) (if `enable_vpn = true`)
- Hetzner Cloud API token

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| hcloud\_token | Hetzner Cloud API token - set via TF\_VAR\_hcloud\_token env var | `string` | n/a | yes |
| argocd\_version | ArgoCD Helm chart version | `string` | `"9.4.2"` | no |
| cilium\_version | Cilium Helm chart version | `string` | `"1.19.0"` | no |
| cluster\_name | Name of the Kubernetes cluster | `string` | `"talos-k8s"` | no |
| control\_plane\_count | Number of control plane nodes (must be odd) | `number` | `3` | no |
| control\_plane\_locations | Locations for control plane nodes | `list(string)` | <pre>[<br/>  "fsn1",<br/>  "nbg1",<br/>  "hel1"<br/>]</pre> | no |
| control\_plane\_server\_type | Hetzner server type for control plane nodes | `string` | `"cx33"` | no |
| delete\_protection | Enable Hetzner delete/rebuild protection | `bool` | `false` | no |
| enable\_argocd | Install ArgoCD | `bool` | `true` | no |
| enable\_csi | Install Hetzner CSI driver | `bool` | `true` | no |
| enable\_etcd\_backup | Enable periodic etcd backups to S3-compatible storage via Kubernetes CronJob | `bool` | `false` | no |
| enable\_vpn | Deploy WireGuard VPN gateway for secure private access | `bool` | `true` | no |
| etcd\_backup\_retention | Number of etcd backup snapshots to retain | `number` | `10` | no |
| etcd\_backup\_s3\_access\_key | S3 access key for etcd backups | `string` | `""` | no |
| etcd\_backup\_s3\_bucket | S3 bucket name for etcd backups | `string` | `""` | no |
| etcd\_backup\_s3\_endpoint | S3-compatible endpoint for etcd backups | `string` | `""` | no |
| etcd\_backup\_s3\_secret\_key | S3 secret key for etcd backups | `string` | `""` | no |
| etcd\_backup\_schedule | Cron schedule for etcd backups | `string` | `"0 */6 * * *"` | no |
| hcloud\_ccm\_version | Hetzner Cloud Controller Manager version | `string` | `"1.30.0"` | no |
| hcloud\_csi\_version | Hetzner CSI driver Helm chart version | `string` | `"2.19.0"` | no |
| kubernetes\_version | Kubernetes version | `string` | `"1.35.0"` | no |
| location | Primary Hetzner datacenter location | `string` | `"fsn1"` | no |
| metrics\_server\_version | Metrics Server Helm chart version | `string` | `"3.13.0"` | no |
| network\_cidr | Main network CIDR | `string` | `"10.0.0.0/8"` | no |
| network\_zone | Hetzner network zone | `string` | `"eu-central"` | no |
| talos\_extensions | Talos system extensions to include | `list(string)` | <pre>[<br/>  "siderolabs/qemu-guest-agent",<br/>  "siderolabs/iscsi-tools",<br/>  "siderolabs/util-linux-tools"<br/>]</pre> | no |
| talos\_version | Talos Linux version | `string` | `"v1.12.4"` | no |
| vpn\_server\_type | Hetzner server type for VPN gateway | `string` | `"cx33"` | no |
| vpn\_subnet\_cidr | VPN gateway subnet CIDR | `string` | `"10.0.0.0/24"` | no |
| wireguard\_client\_ip | WireGuard client IP address | `string` | `"10.100.0.2"` | no |
| wireguard\_port | WireGuard listen port | `number` | `51820` | no |
| wireguard\_vpn\_cidr | WireGuard VPN tunnel CIDR | `string` | `"10.100.0.0/24"` | no |
| worker\_nodepools | Worker node pools | <pre>list(object({<br/>    name        = string<br/>    count       = number<br/>    server_type = string<br/>    locations   = list(string)<br/>    labels      = optional(map(string), {})<br/>    taints      = optional(list(string), [])<br/>  }))</pre> | <pre>[<br/>  {<br/>    "count": 3,<br/>    "locations": [<br/>      "fsn1",<br/>      "nbg1",<br/>      "hel1"<br/>    ],<br/>    "name": "default",<br/>    "server_type": "cx33"<br/>  }<br/>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster\_summary | Summary of deployed resources |
| connection\_info | Connection information for the cluster |
| control\_plane\_ips | Public IPs of control plane nodes |
| control\_plane\_private\_ips | Private IPs of control plane nodes |
| k8s\_api\_lb\_ip | Private IP of the Kubernetes API load balancer |
| kubeconfig | Kubeconfig for kubectl access (uses private LB IP) |
| kubeconfig\_public | Kubeconfig using public CP IP (direct access) |
| kubeconfig\_tunnel | Kubeconfig via SSH tunnel (use with: ./deploy.sh tunnel) |
| talosconfig | Talosconfig for talosctl access |
| vpn\_gateway\_private\_ip | Private IP of the VPN gateway |
| vpn\_gateway\_public\_ip | Public IP of the VPN gateway |
| vpn\_ssh\_private\_key | SSH private key to access VPN gateway |
| wireguard\_client\_config | Instructions to get WireGuard client config from VPN gateway |
<!-- END_TF_DOCS -->
