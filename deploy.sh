#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()     { echo -e "${BLUE}==>${NC} $1"; }
success() { echo -e "${GREEN}==>${NC} $1"; }
warn()    { echo -e "${YELLOW}==>${NC} $1"; }
error()   { echo -e "${RED}==>${NC} $1"; exit 1; }

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ServerAliveInterval=30"

get_enable_vpn() {
    if [[ -f terraform.tfvars ]]; then
        local value
        value=$(grep -E '^enable_vpn\s*=' terraform.tfvars | sed 's/.*= *//' | tr -d '"' | tr -d ' ')
        [[ -n "$value" ]] && echo "$value" && return
    fi
    echo "true"
}

check_prerequisites() {
    log "Checking prerequisites..."

    command -v tofu    >/dev/null 2>&1 || error "opentofu is not installed (https://opentofu.org/docs/intro/install/)"
    command -v hcloud  >/dev/null 2>&1 || error "hcloud CLI is not installed (https://github.com/hetznercloud/cli)"
    command -v kubectl >/dev/null 2>&1 || error "kubectl is not installed"
    command -v helm    >/dev/null 2>&1 || error "helm is not installed (https://helm.sh/docs/intro/install/)"
    command -v jq      >/dev/null 2>&1 || error "jq is not installed"

    if [[ "$(get_enable_vpn)" == "true" ]]; then
        command -v wg-quick >/dev/null 2>&1 || error "wireguard-tools is not installed (required when enable_vpn=true)"
    fi

    if [[ -f .env ]]; then
        set -a; source .env; set +a
    fi

    HCLOUD_TOKEN="${HCLOUD_TOKEN:-${TF_VAR_hcloud_token:-}}"
    TF_VAR_hcloud_token="${TF_VAR_hcloud_token:-${HCLOUD_TOKEN:-}}"
    export HCLOUD_TOKEN TF_VAR_hcloud_token

    [[ -z "${HCLOUD_TOKEN:-}" ]] && \
        error "No Hetzner token found. Set HCLOUD_TOKEN or TF_VAR_hcloud_token (or create .env)"

    success "Prerequisites OK"
}

# --- Deploy ---

deploy_with_vpn() {
    log "Deploying..."
    tofu init -upgrade >/dev/null
    tofu apply -auto-approve || error "Deployment failed"

    local vpn_ip ssh_key_file wg_config
    vpn_ip=$(tofu output -raw vpn_gateway_public_ip)
    ssh_key_file="/tmp/vpn-deploy-key-$$"
    wg_config="/tmp/wg-hetzner.conf"

    tofu output -raw vpn_ssh_private_key > "$ssh_key_file"
    chmod 600 "$ssh_key_file"

    log "Fetching WireGuard config..."
    for i in {1..30}; do
        ssh $SSH_OPTS -o ConnectTimeout=5 -i "$ssh_key_file" root@"$vpn_ip" \
            'cat /etc/wireguard/client.conf' > "$wg_config" 2>/dev/null && break
        echo -n "."
        sleep 5
    done
    echo ""
    rm -f "$ssh_key_file"

    log "Connecting to VPN..."
    sudo wg-quick down "$wg_config" 2>/dev/null || true
    sudo wg-quick up "$wg_config"

    mkdir -p ~/.kube
    tofu output -raw kubeconfig_public > ~/.kube/hetzner 2>/dev/null || true

    success "Deployment complete (VPN connected)"
    echo "  WireGuard config: $wg_config"
    echo "  Kubeconfig:       ~/.kube/hetzner"
    echo ""
    echo "  export KUBECONFIG=~/.kube/hetzner"
    echo "  kubectl get nodes"
}

deploy_without_vpn() {
    log "Deploying..."
    tofu init -upgrade >/dev/null
    tofu apply -auto-approve || error "Deployment failed"

    mkdir -p ~/.kube
    tofu output -raw kubeconfig_public > ~/.kube/hetzner 2>/dev/null || true

    success "Deployment complete"
    echo "  Kubeconfig: ~/.kube/hetzner"
    echo ""
    echo "  export KUBECONFIG=~/.kube/hetzner"
    echo "  kubectl get nodes"
}

# --- Destroy ---

destroy_infrastructure() {
    warn "This will destroy all infrastructure!"
    read -p "Are you sure? (yes/no): " confirm
    [[ "$confirm" != "yes" ]] && echo "Aborted." && exit 0

    if [[ "$(get_enable_vpn)" == "true" ]]; then
        log "Disconnecting VPN..."
        sudo wg-quick down /tmp/wg-hetzner.conf 2>/dev/null || true
    fi

    # These resources use local-exec provisioners that need cluster access — remove from state
    log "Removing cluster resources from state..."
    tofu state rm 'module.cluster.terraform_data.cluster_ready' 2>/dev/null || true
    tofu state rm 'module.cluster.terraform_data.cilium' 2>/dev/null || true
    tofu state rm 'module.cluster.terraform_data.metrics_server' 2>/dev/null || true
    tofu state rm 'module.cluster.terraform_data.hcloud_csi' 2>/dev/null || true
    tofu state rm 'terraform_data.argocd' 2>/dev/null || true
    tofu state rm 'terraform_data.etcd_backup' 2>/dev/null || true

    log "Destroying infrastructure..."
    tofu destroy -auto-approve

    success "Infrastructure destroyed"
}

# --- VPN ---

vpn_ssh_key() {
    local key_file="${1:-/tmp/vpn-key}"
    tofu output -raw vpn_ssh_private_key > "$key_file"
    chmod 600 "$key_file"
    echo "$key_file"
}

cmd_tunnel() {
    [[ "$(get_enable_vpn)" != "true" ]] && error "Tunnel requires enable_vpn=true"
    mkdir -p ~/.kube
    tofu output -raw kubeconfig_tunnel > ~/.kube/hetzner

    local vpn_ip key_file lb_ip
    vpn_ip=$(tofu output -raw vpn_gateway_public_ip)
    key_file=$(vpn_ssh_key)
    lb_ip=$(tofu output -raw k8s_api_lb_ip)

    log "Tunnel to K8s API via $vpn_ip (127.0.0.1:16443 -> $lb_ip:6443)"
    log "Press Ctrl+C to close"
    ssh -N -L "16443:$lb_ip:6443" $SSH_OPTS -i "$key_file" "root@$vpn_ip"
    rm -f "$key_file"
}

# --- Main ---

usage() {
    cat <<EOF
Usage: $0 <command>

Commands:
  deploy      Deploy infrastructure (with VPN: also connects WireGuard)
  destroy     Destroy all infrastructure
  tunnel      SSH tunnel to K8s API (alternative to full VPN)
  vpn-up      Connect to WireGuard VPN
  vpn-down    Disconnect from WireGuard VPN
EOF
}

case "${1:-}" in
    deploy)
        check_prerequisites
        if [[ "$(get_enable_vpn)" == "true" ]]; then
            deploy_with_vpn
        else
            deploy_without_vpn
        fi
        ;;
    destroy)
        check_prerequisites
        destroy_infrastructure
        ;;
    tunnel)
        cmd_tunnel
        ;;
    vpn-up)
        [[ "$(get_enable_vpn)" != "true" ]] && warn "VPN disabled" && exit 0
        [[ ! -f /tmp/wg-hetzner.conf ]] && error "No WireGuard config at /tmp/wg-hetzner.conf. Run deploy first."
        sudo wg-quick up /tmp/wg-hetzner.conf
        ;;
    vpn-down)
        [[ "$(get_enable_vpn)" != "true" ]] && warn "VPN disabled" && exit 0
        sudo wg-quick down /tmp/wg-hetzner.conf 2>/dev/null || true
        success "VPN disconnected"
        ;;
    *)
        usage
        exit 1
        ;;
esac
