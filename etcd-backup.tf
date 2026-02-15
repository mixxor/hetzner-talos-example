# Periodic etcd backups via Kubernetes CronJob.
# Takes etcd snapshot via talosctl, uploads to S3-compatible storage via mc (MinIO client).

resource "terraform_data" "etcd_backup" {
  depends_on = [module.cluster]

  lifecycle {
    enabled = var.enable_etcd_backup
  }

  triggers_replace = [
    var.etcd_backup_s3_endpoint,
    var.etcd_backup_s3_bucket,
    var.etcd_backup_schedule,
    var.etcd_backup_retention,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -eu
      source ./files/kubeconfig-env.sh

      # Create secret with talosconfig and S3 credentials
      kubectl create secret generic etcd-backup-config -n kube-system \
        --from-literal=talosconfig="$TALOSCONFIG" \
        --from-literal=s3-access-key="$S3_ACCESS_KEY" \
        --from-literal=s3-secret-key="$S3_SECRET_KEY" \
        --dry-run=client -o yaml | kubectl apply -f -

      # Deploy CronJob
      cat <<'MANIFEST' | sed \
        -e "s|__SCHEDULE__|$BACKUP_SCHEDULE|g" \
        -e "s|__S3_ENDPOINT__|$S3_ENDPOINT|g" \
        -e "s|__S3_BUCKET__|$S3_BUCKET|g" \
        -e "s|__RETENTION__|$BACKUP_RETENTION|g" \
        -e "s|__TALOS_VERSION__|$TALOS_VERSION|g" \
        -e "s|__CP_NODE_IP__|$CP_NODE_IP|g" \
        | kubectl apply -f -
      apiVersion: batch/v1
      kind: CronJob
      metadata:
        name: etcd-backup
        namespace: kube-system
      spec:
        schedule: "__SCHEDULE__"
        concurrencyPolicy: Forbid
        successfulJobsHistoryLimit: 3
        failedJobsHistoryLimit: 3
        jobTemplate:
          spec:
            backoffLimit: 1
            activeDeadlineSeconds: 600
            template:
              spec:
                restartPolicy: Never
                nodeSelector:
                  node-role.kubernetes.io/control-plane: ""
                tolerations:
                  - key: node-role.kubernetes.io/control-plane
                    effect: NoSchedule
                containers:
                  - name: etcd-backup
                    image: alpine:3.20
                    command: ["/bin/sh", "-c"]
                    args:
                      - |
                        set -eu
                        TALOS_VER="__TALOS_VERSION__"
                        S3_EP="__S3_ENDPOINT__"
                        S3_BKT="__S3_BUCKET__"
                        KEEP=__RETENTION__
                        CP="__CP_NODE_IP__"
                        echo "Installing talosctl and mc..."
                        wget -qO /usr/local/bin/talosctl "https://github.com/siderolabs/talos/releases/download/$TALOS_VER/talosctl-linux-amd64"
                        chmod +x /usr/local/bin/talosctl
                        wget -qO /usr/local/bin/mc "https://dl.min.io/client/mc/release/linux-amd64/mc"
                        chmod +x /usr/local/bin/mc
                        TS=$(date +%Y%m%d-%H%M%S)
                        SNAP="/tmp/etcd-$TS.snapshot"
                        echo "Taking etcd snapshot from $CP..."
                        talosctl --talosconfig /config/talosconfig -n "$CP" etcd snapshot "$SNAP"
                        echo "Snapshot: $(du -h "$SNAP" | cut -f1)"
                        echo "Configuring S3..."
                        mc alias set backup "$S3_EP" "$(cat /config/s3-access-key)" "$(cat /config/s3-secret-key)"
                        echo "Uploading to s3://$S3_BKT/etcd-backups/..."
                        mc cp "$SNAP" "backup/$S3_BKT/etcd-backups/etcd-$TS.snapshot"
                        echo "Rotating old snapshots (keeping $KEEP)..."
                        mc ls "backup/$S3_BKT/etcd-backups/" --json | grep -o '"key":"[^"]*"' | sed 's/"key":"//;s/"//' | sort -r | tail -n +$((KEEP + 1)) | while read -r old; do
                          echo "Removing $old"
                          mc rm "backup/$S3_BKT/etcd-backups/$old"
                        done
                        echo "Backup complete."
                    volumeMounts:
                      - name: config
                        mountPath: /config
                        readOnly: true
                    resources:
                      requests:
                        cpu: 100m
                        memory: 256Mi
                      limits:
                        memory: 512Mi
                volumes:
                  - name: config
                    secret:
                      secretName: etcd-backup-config
      MANIFEST
    EOT
    environment = {
      KUBECONFIG_B64   = base64encode(module.cluster.kubeconfig_public)
      TALOSCONFIG      = module.cluster.talosconfig
      S3_ACCESS_KEY    = var.etcd_backup_s3_access_key
      S3_SECRET_KEY    = var.etcd_backup_s3_secret_key
      S3_ENDPOINT      = var.etcd_backup_s3_endpoint
      S3_BUCKET        = var.etcd_backup_s3_bucket
      BACKUP_SCHEDULE  = var.etcd_backup_schedule
      BACKUP_RETENTION = tostring(var.etcd_backup_retention)
      TALOS_VERSION    = var.talos_version
      CP_NODE_IP       = module.cluster.control_plane_private_ips[0]
    }
  }

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = "echo 'Etcd backup CronJob: will be removed with cluster'"
  }
}
