#!/usr/bin/env bash
#
# SCRIPT: Velero Objects-Only Restore Test
#
# DESCRIPTION:
# This script performs an automated test of Velero's ability to back up and restore
# Kubernetes object definitions (metadata) without their associated Persistent Volume Claims (PVCs).
# It's designed to validate a disaster recovery scenario for stateless applications or
# when application data is managed separately.
#
# The flow is as follows:
# 1. Configure source/destination namespaces and artifact locations.
# 2. Create a volume-snapshot-less backup of specified namespaces.
# 3. Restore objects from the source namespace into a new, unique namespace.
# 4. Immediately scale down all restored workloads to 0 to prevent pods from getting stuck in a Pending state.
# 5. Collect logs and resource inventories as evidence.
# 6. Package all artifacts into a single tarball.
# 7. Clean up by deleting the temporary restore namespace.
#

# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error.
# Note: 'pipefail' is not set, so commands like 'grep' or 'jsonpath' with no matches won't terminate the script.
set -eu

# --- 0) Script Configuration ---

# Source namespace to be backed up and restored.
SOURCE_NAMESPACE="${SOURCE_NAMESPACE:-prod}"
# Base directory for storing test artifacts (logs, manifests).
ARTIFACTS_BASE_DIR="${ARTIFACTS_BASE_DIR:-/home/test/k8s-audit}"
# Cleanup mode: 'ns' to delete the test namespace after run, 'none' to keep it for inspection.
CLEANUP_MODE="${CLEANUP_MODE:-ns}"

# --- 1) Logging & Runtime Variables ---

log() { printf "%s [%s] %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$1" "$2"; }
INFO() { log INFO "$1"; }
WARN() { log WARN "$1"; }
ERR()  { log ERR  "$1"; }

DATE_STAMP="$(date +%F)"      # e.g., 2025-08-17
TIME_STAMP="$(date +%H%M%S)"  # e.g., 154210
RUN_ID="${DATE_STAMP}_${TIME_STAMP}"

# Directory for this specific test run's artifacts.
ARTIFACT_PATH="${ARTIFACTS_BASE_DIR}/${RUN_ID}"

# Unique names for the backup, restore, and destination namespace.
DESTINATION_NAMESPACE="${DESTINATION_NAMESPACE:-prod-restore-test-${TIME_STAMP}}"
BACKUP_NAME="${BACKUP_NAME:-objects-only-backup-${RUN_ID}}"
RESTORE_NAME="${RESTORE_NAME:-objects-only-restore-${RUN_ID}}"

mkdir -p "$ARTIFACT_PATH"
# Redirect stdout and stderr to both the console and a log file.
exec > >(tee -a "$ARTIFACT_PATH/procedure.log") 2>&1

INFO "Test run artifacts will be saved to: $ARTIFACT_PATH"
INFO "For Windows/WSL users, access via: \\\\wsl.localhost\\Ubuntu${ARTIFACT_PATH}"

# --- 2) Velero Health Check ---
INFO "Performing Velero health check (pods and permissions)..."
# These checks are for evidence gathering; '|| true' prevents script exit on failure.
kubectl -n velero get deploy,po | tee "$ARTIFACT_PATH/00-velero-pods.txt" || true
kubectl -n velero auth can-i --as=system:serviceaccount:velero:velero --list \
  | tee "$ARTIFACT_PATH/00-velero-rbac.txt" || true

# --- 3) Create Objects-Only Backup ---
INFO "Creating backup: ${BACKUP_NAME}"
velero backup create "$BACKUP_NAME" \
  --include-namespaces prod,dev,traefik,monitoring \
  --exclude-namespaces argocd \
  --snapshot-volumes=false \
  --wait

INFO "Saving backup details and logs..."
velero backup describe "$BACKUP_NAME" --details | tee "$ARTIFACT_PATH/01-backup-describe.txt" || true
velero backup logs "$BACKUP_NAME" | tee "$ARTIFACT_PATH/02-backup-logs.txt" || true

# --- 4) Restore to a New, Unique Namespace ---
INFO "Creating destination namespace: ${DESTINATION_NAMESPACE}"
kubectl create ns "$DESTINATION_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

INFO "Restoring from backup ${BACKUP_NAME} into ${DESTINATION_NAMESPACE}"
velero restore create "$RESTORE_NAME" \
  --from-backup "$BACKUP_NAME" \
  --include-namespaces "$SOURCE_NAMESPACE" \
  --namespace-mappings "$SOURCE_NAMESPACE:$DESTINATION_NAMESPACE" \
  --include-cluster-resources=false \
  --exclude-resources \
ingress,ingresses.networking.k8s.io,ingressroute.traefik.containo.us,ingressroutetcp.traefik.containo.us,ingressrouteudp.traefik.containo.us,ingressroute.traefik.io,ingressroutetcp.traefik.io,ingressrouteudp.traefik.io,pods \
  --wait

INFO "Saving restore details and logs..."
velero restore describe "$RESTORE_NAME" --details | tee "$ARTIFACT_PATH/03-restore-describe.txt" || true
velero restore logs "$RESTORE_NAME" | tee "$ARTIFACT_PATH/04-restore-logs.txt" || true

# --- 5) Immediately Scale Down Workloads to Prevent Pending Pods ---
INFO "Scaling down Deployments/StatefulSets to 0 and suspending CronJobs in ${DESTINATION_NAMESPACE}"
# This is a critical step. Since PVCs were not restored, any created pods would get stuck in a 'Pending' state.
# We scale down all workloads to prevent this.

# Scale Deployments to 0 replicas
kubectl -n "$DESTINATION_NAMESPACE" get deploy -o name | xargs -r -I{} kubectl -n "$DESTINATION_NAMESPACE" scale {} --replicas=0 || true
# Scale StatefulSets to 0 replicas
kubectl -n "$DESTINATION_NAMESPACE" get statefulset -o name | xargs -r -I{} kubectl -n "$DESTINATION_NAMESPACE" scale {} --replicas=0 || true
# Suspend CronJobs to prevent them from creating new Jobs/Pods
kubectl -n "$DESTINATION_NAMESPACE" get cronjob -o name | xargs -r -I{} kubectl -n "$DESTINATION_NAMESPACE" patch {} -p '{"spec":{"suspend":true}}' || true
# Force-delete any pods that might have been created in the meantime
kubectl -n "$DESTINATION_NAMESPACE" delete pod --all --wait=false || true

# --- 6) Inventory of Restored Resources ---
INFO "Listing restored resources in namespace ${DESTINATION_NAMESPACE}..."
kubectl -n "$DESTINATION_NAMESPACE" get deploy,svc,cm,secret,networkpolicy,pvc -o wide \
  | tee "$ARTIFACT_PATH/05-ns-inventory.txt" || true

# --- 7) Package Evidence Artifacts ---
EVIDENCE_PKG_NAME="metadata-restore-proof-${RUN_ID}.tar.gz"
INFO "Creating evidence package: ${EVIDENCE_PKG_NAME}"
tar -czf "$ARTIFACT_PATH/${EVIDENCE_PKG_NAME}" -C "$ARTIFACT_PATH" . || true
INFO "Evidence package created successfully: $ARTIFACT_PATH/${EVIDENCE_PKG_NAME}"

# --- 8) Final Cleanup ---
case "$CLEANUP_MODE" in
  ns)
    INFO "CLEANUP_MODE=ns -> Deleting the test namespace: ${DESTINATION_NAMESPACE}"
    kubectl delete ns "$DESTINATION_NAMESPACE" || true
    ;;
  none)
    INFO "CLEANUP_MODE=none -> Leaving test namespace and resources for manual inspection (no pods will be running)."
    ;;
  *)
    WARN "Unknown CLEANUP_MODE='${CLEANUP_MODE}'. Use 'ns' or 'none'. No cleanup will be performed."
    ;;
esac

INFO "Script finished."
INFO "Artifacts are located in: $ARTIFACT_PATH"
INFO "For Windows/WSL users, access via: \\\\wsl.localhost\\Ubuntu${ARTIFACT_PATH}"