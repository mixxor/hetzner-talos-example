resource "terraform_data" "argocd" {
  triggers_replace = [var.argocd_version]

  depends_on = [module.cluster]

  lifecycle {
    enabled = var.enable_argocd
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -eu
      source ./files/kubeconfig-env.sh
      echo "$ARGOCD_VALUES" | helm upgrade --install argocd argo-cd \
        --repo https://argoproj.github.io/argo-helm \
        --version "$ARGOCD_VERSION" \
        --namespace argocd --create-namespace \
        --values - \
        --wait --timeout 10m
    EOT
    environment = {
      KUBECONFIG_B64 = base64encode(module.cluster.kubeconfig_public)
      ARGOCD_VERSION = var.argocd_version
      ARGOCD_VALUES = yamlencode({
        server = {
          service = {
            type = "ClusterIP"
          }
        }
        configs = {
          params = {
            "server.insecure" = true
          }
        }
      })
    }
  }

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = "echo 'Skipping ArgoCD uninstall'"
  }
}
