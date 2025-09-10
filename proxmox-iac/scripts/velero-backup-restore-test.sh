#!/usr/bin/env bash
# ===== VELERO BACKUP/RESTORE TEST — objects-only variant, no PVCs, no Pending =====
set -eu  # no pipefail — grep/jsonpath without matches won't terminate the session

log(){ printf "%s [%s] %s\n" "$(date +%F\ %T)" "$1" "$2"; }
INFO(){ log INFO "$1"; }
WARN(){ log WARN "$1"; }
ERR(){  log ERR  "$1"; }

# --- 0) User configuration
SRC_NS="${SRC_NS:-prod}"                 # source namespace to be restored
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_BASE="${OUT_BASE:-${SCRIPT_DIR}/audit}"
CLEANUP_MODE="${CLEANUP_MODE:-ns}"      # ns|none  (default = delete the entire test namespace)

# --- 1) Timestamps, paths, and backup/restore names
D="$(date +%F)"              # e.g. 2025-08-17
STAMP="$(date +%H%M%S)"      # e.g. 154210
DIR="${D}_${STAMP}"
OUT="${OUT_BASE}/${DIR}"
DST_NS="${DST_NS:-prod-restore-rbac-${STAMP}}"
BCK="${BCK:-post-rbac-${D}-${STAMP}}"
RES="${RES:-post-rbac-restore-${D}-${STAMP}}"

mkdir -p "$OUT"
exec > >(tee -a "$OUT/procedure.log") 2>&1
INFO "Artifacts: $OUT"
INFO "Windows/WSL: \\\\wsl.localhost\\Ubuntu${OUT}"

# --- 2) Velero healthcheck (for logs only; does not interrupt the test)
INFO "Velero healthcheck (pods/permissions)"
kubectl -n velero get deploy,po | tee "$OUT/00-velero-pods.txt" || true
kubectl -n velero auth can-i --as=system:serviceaccount:velero:velero --list \
  | tee "$OUT/00-velero-rbac.txt" || true

# --- 3) Backup (object-only, no PVC snapshots)
INFO "Backup: ${BCK}"
velero backup create "$BCK" \
  --include-namespaces prod,dev,traefik,monitoring \
  --exclude-namespaces argocd \
  --snapshot-volumes=false \
  --wait

velero backup describe "$BCK" --details | tee "$OUT/01-backup-describe.txt" || true
velero backup logs "$BCK"               | tee "$OUT/02-backup-logs.txt"     || true

# --- 4) Restore into a UNIQUE namespace (excluding Ingress and cluster-wide resources)
INFO "Target namespace: ${DST_NS}"
kubectl create ns "$DST_NS" --dry-run=client -o yaml | kubectl apply -f -

INFO "Restore: ${RES} from ${BCK} → ${DST_NS}"
velero restore create "$RES" \
  --from-backup "$BCK" \
  --include-namespaces "$SRC_NS" \
  --namespace-mappings "$SRC_NS:$DST_NS" \
  --include-cluster-resources=false \
  --exclude-resources \
ingress,ingresses.networking.k8s.io,ingressroute.traefik.containo.us,ingressroutetcp.traefik.containo.us,ingressrouteudp.traefik.containo.us,ingressroute.traefik.io,ingressroutetcp.traefik.io,ingressrouteudp.traefik.io,pods \
  --wait

velero restore describe "$RES" --details | tee "$OUT/03-restore-describe.txt" || true
velero restore logs "$RES"               | tee "$OUT/04-restore-logs.txt"     || true

# --- 5) IMMEDIATELY stop workloads to avoid Pending (zero pods)
INFO "Scaling Deploy/StatefulSet to 0 and suspending CronJobs in ${DST_NS}"
# Deployments → 0
kubectl -n "$DST_NS" get deploy -o name | xargs -r -I{} kubectl -n "$DST_NS" scale {} --replicas=0 || true
# StatefulSets → 0
kubectl -n "$DST_NS" get statefulset -o name | xargs -r -I{} kubectl -n "$DST_NS" scale {} --replicas=0 || true
# CronJobs → suspend=true (to avoid spawning Jobs/pods)
kubectl -n "$DST_NS" get cronjob -o name | xargs -r -I{} kubectl -n "$DST_NS" patch {} -p '{"spec":{"suspend":true}}' || true
# Delete ALL pods that may have already started (non-blocking)
kubectl -n "$DST_NS" delete pod --all --wait=false || true

# --- 6) Post-restore resource inventory (objects-only)
kubectl -n "$DST_NS" get deploy,svc,cm,secret,networkpolicy,pvc -o wide \
  | tee "$OUT/05-ns-inventory.txt" || true

# --- 7) Archive of all logs and outputs
tar -czf "$OUT/post-rbac-restore-proof-${D}-${STAMP}.tar.gz" -C "$OUT" . || true
INFO "Archive ready: $OUT/post-rbac-restore-proof-${D}-${STAMP}.tar.gz"

# --- 8) Final cleanup depending on mode
case "$CLEANUP_MODE" in
  ns)
    INFO "CLEANUP_MODE=ns → deleting test namespace: ${DST_NS}"
    kubectl delete ns "$DST_NS" || true
    ;;
  none)
    INFO "CLEANUP_MODE=none → keeping namespace and test resources (no pods will run)"
    ;;
  *)
    WARN "Unknown CLEANUP_MODE='${CLEANUP_MODE}', use 'ns' or 'none'."
    ;;
esac

INFO "Done. Artifacts: $OUT"
INFO "Windows/WSL: \\\\wsl.localhost\\Ubuntu${OUT}"
