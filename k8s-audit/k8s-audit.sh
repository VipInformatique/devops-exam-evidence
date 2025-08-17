#!/usr/bin/env bash
# K8s Pre-RBAC/NP Audit — A→Z (with single-file report)
# Safe: read-only; exits on error but tolerates missing resources.
set -euo pipefail

# === [A] BASICS / PATHS ===
TS="$(date +%F_%H%M%S)"
BASE_DIR="${HOME}/k8s-audit/${TS}"
CTX="$(kubectl config current-context 2>/dev/null || echo unknown)"
mkdir -p "${BASE_DIR}"/{00-context,10-api,20-cluster,30-ns,40-crd,50-rbac,60-network,70-storage,80-workloads,90-policies,95-webhooks,98-others}

# Preferred namespaces to detail if present
PREF_NS=("prod" "dev" "traefik" "cloudflare" "monitoring" "kube-system")
# All namespaces
mapfile -t ALL_NS < <(kubectl get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | sort)

# Helper: run command and save stdout/stderr to file
save() {
  local file="$1"; shift
  echo "[*] $*  ->  ${file}"
  # Ensure parent dir exists
  mkdir -p "$(dirname "$file")"
  "$@" > "${file}" 2>&1 || true
}

# === [B] CONTEXT / VERSIONS / API RESOURCES ===
save "${BASE_DIR}/00-context/context.txt"                kubectl config current-context
# Robust version capture (client always, server if reachable)
save "${BASE_DIR}/00-context/version-client.yaml"        kubectl version --client --output=yaml
save "${BASE_DIR}/00-context/version.yaml"               bash -lc 'kubectl version --output=yaml || true'
save "${BASE_DIR}/00-context/cluster-info.txt"           kubectl cluster-info
save "${BASE_DIR}/00-context/apiservices.txt"            kubectl get apiservices
save "${BASE_DIR}/10-api/api-resources.txt"              bash -lc 'kubectl api-resources -o wide | column -t'
save "${BASE_DIR}/20-cluster/nodes-wide.txt"             kubectl get nodes -o wide
save "${BASE_DIR}/20-cluster/nodes-describe.txt"         kubectl describe nodes
save "${BASE_DIR}/30-ns/namespaces-with-labels.txt"      kubectl get ns --show-labels

# === [C] CRDs (custom resource definitions) ===
save "${BASE_DIR}/40-crd/crds.txt"                       kubectl get crds
save "${BASE_DIR}/40-crd/crds-names.txt"                 kubectl get crds -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'

# === [D] RBAC — OVERVIEW & SNAPSHOT ===
save "${BASE_DIR}/50-rbac/sa-all.txt"                    kubectl get serviceaccounts -A -o wide
save "${BASE_DIR}/50-rbac/roles-rolebindings.txt"        kubectl get roles,rolebindings -A -o wide
save "${BASE_DIR}/50-rbac/clusterroles-bindings.txt"     kubectl get clusterroles,clusterrolebindings -o wide
mkdir -p "${BASE_DIR}/50-rbac/snapshot"
save "${BASE_DIR}/50-rbac/snapshot/roles.yaml"           kubectl get roles -A -o yaml
save "${BASE_DIR}/50-rbac/snapshot/rolebindings.yaml"    kubectl get rolebindings -A -o yaml
save "${BASE_DIR}/50-rbac/snapshot/clusterroles.yaml"    kubectl get clusterroles -o yaml
save "${BASE_DIR}/50-rbac/snapshot/clusterrolebindings.yaml" kubectl get clusterrolebindings -o yaml
save "${BASE_DIR}/50-rbac/my-perms.txt"                  kubectl auth can-i --list

# === [E] NETWORK / CNI / DNS ===
# Full list of kube-system DaemonSets
save "${BASE_DIR}/60-network/daemonsets-kube-system.txt" kubectl -n kube-system get ds -o wide
# Try to detect known CNIs; fallback with explanation if none matched
CNI_OUT="${BASE_DIR}/60-network/cni-detector.txt"
bash -lc "kubectl -n kube-system get ds -o wide | egrep -i 'cilium|calico|flannel|weave|antrea|kube-router|ovn|canal' > '${CNI_OUT}'" || true
if [ ! -s "${CNI_OUT}" ]; then
  bash -lc "kubectl -n kube-system get pods -o wide | egrep -i 'cilium|calico|flannel|weave|antrea|kube-router|ovn|canal' >> '${CNI_OUT}'" || true
fi
if [ ! -s "${CNI_OUT}" ]; then
  bash -lc "kubectl -n kube-system get cm | egrep -i 'cilium|calico|flannel|weave|antrea|kube-router|ovn|canal' >> '${CNI_OUT}'" || true
fi
if [ ! -s "${CNI_OUT}" ]; then
  echo "No known CNI DaemonSet/Pod/ConfigMap matched. See 60-network/daemonsets-kube-system.txt for full list." > "${CNI_OUT}"
fi
save "${BASE_DIR}/60-network/services-kube-system.txt"   kubectl -n kube-system get svc -o wide
save "${BASE_DIR}/60-network/kube-dns.txt"               kubectl -n kube-system get svc kube-dns -o wide

# === [F] STORAGE ===
save "${BASE_DIR}/70-storage/storageclasses.txt"         kubectl get storageclasses
save "${BASE_DIR}/70-storage/pv-wide.txt"                kubectl get pv -o wide
save "${BASE_DIR}/70-storage/pvc-wide.txt"               kubectl get pvc -A -o wide

# === Helpers for namespaces ===
ns_exists() { kubectl get ns "$1" >/dev/null 2>&1; }
dump_ns_basic() {
  local ns="$1"
  local dir="${BASE_DIR}/80-workloads/${ns}"
  mkdir -p "${dir}"
  save "${dir}/deploy.txt"         kubectl -n "${ns}" get deploy -o wide
  save "${dir}/statefulsets.txt"   kubectl -n "${ns}" get statefulsets -o wide
  save "${dir}/daemonsets.txt"     kubectl -n "${ns}" get daemonsets -o wide
  save "${dir}/jobs.txt"           kubectl -n "${ns}" get jobs
  save "${dir}/cronjobs.txt"       kubectl -n "${ns}" get cronjobs
  save "${dir}/pods-wide.txt"      kubectl -n "${ns}" get pods -o wide
  save "${dir}/svc-wide.txt"       kubectl -n "${ns}" get svc -o wide
  save "${dir}/endpoints.txt"      kubectl -n "${ns}" get endpoints
  save "${dir}/endpointslices.txt" kubectl -n "${ns}" get endpointslices
  save "${dir}/cm-secrets.txt"     kubectl -n "${ns}" get cm,secret
  save "${dir}/labels-deploy.txt"  kubectl -n "${ns}" get deploy -o custom-columns=NAME:.metadata.name,LABELS:.spec.template.metadata.labels
}

# === [G] WORKLOADS + SERVICES (preferred namespaces + the rest) ===
for ns in "${PREF_NS[@]}"; do
  ns_exists "$ns" && dump_ns_basic "$ns" || true
done
for ns in "${ALL_NS[@]}"; do
  skip=0
  for p in "${PREF_NS[@]}"; do [[ "$ns" == "$p" ]] && skip=1 && break; done
  [[ $skip -eq 0 ]] && dump_ns_basic "$ns"
done

# === [H] INGRESS / TRAEFIK CRDs (if present) ===
has_res() { kubectl api-resources | awk '{print $1}' | grep -qx "$1"; }
if has_res ingress; then
  save "${BASE_DIR}/80-workloads/ingress.txt"            kubectl get ingress -A -o wide
fi
for r in ingressroutes ingressroutetcps ingressrouteudps middlewares traefikservices tlsoptions tlsstores; do
  if has_res "$r"; then
    save "${BASE_DIR}/80-workloads/${r}.yaml"            kubectl get "$r" -A -o yaml
  fi
done

# === [I] POLICIES: NetworkPolicy, PDB, HPA/VPA, Quotas, LimitRanges ===
save "${BASE_DIR}/90-policies/networkpolicies.yaml"      kubectl get networkpolicies -A -o yaml
save "${BASE_DIR}/90-policies/pdb.txt"                   kubectl get pdb -A
save "${BASE_DIR}/90-policies/hpa.txt"                   kubectl get hpa -A
save "${BASE_DIR}/90-policies/vpa.txt"                   kubectl get vpa -A
save "${BASE_DIR}/90-policies/resourcequotas.txt"        kubectl get resourcequota -A
save "${BASE_DIR}/90-policies/limitranges.txt"           kubectl get limitrange -A
# Pod Security Admission labels (if used)
save "${BASE_DIR}/90-policies/psa-labels.txt"            bash -lc "kubectl get ns -o jsonpath='{range .items[*]}{.metadata.name}{\"  \"}{.metadata.labels.pod-security\\.kubernetes\\.io/enforce}{\"\\n\"}{end}'"

# === [J] WEBHOOKS ===
save "${BASE_DIR}/95-webhooks/mutating.txt"              kubectl get mutatingwebhookconfigurations -A -o wide
save "${BASE_DIR}/95-webhooks/validating.txt"            kubectl get validatingwebhookconfigurations -A -o wide
save "${BASE_DIR}/95-webhooks/mutating.yaml"             kubectl get mutatingwebhookconfigurations -A -o yaml
save "${BASE_DIR}/95-webhooks/validating.yaml"           kubectl get validatingwebhookconfigurations -A -o yaml

# === [K] EVENTS / METRICS (best-effort) ===
save "${BASE_DIR}/98-others/events-latest.txt"           bash -lc 'kubectl get events -A --sort-by=.lastTimestamp | tail -n 200'
save "${BASE_DIR}/98-others/top-nodes.txt"               kubectl top nodes
save "${BASE_DIR}/98-others/top-pods.txt"                kubectl top pods -A

# === [L] README: Post-deploy tests template ===
cat > "${BASE_DIR}/98-others/README-tests.txt" <<'EOF'
[Post-deploy Tests Template]
1) RBAC quick audit:
   kubectl auth can-i --as=system:serviceaccount:prod:devistor-sa get secrets -n prod
   kubectl auth can-i --as=system:serviceaccount:prod:devistor-sa create secrets -n prod

2) Netshoot test pod:
   kubectl -n prod run np-test --image=nicolaka/netshoot -it --rm -- sh

3) DNS from pod:
   drill kubernetes.default.svc.cluster.local @kube-dns.kube-system.svc.cluster.local

4) Egress to Neon (example):
   tcping -t 3 <YOUR-NEON-HOSTNAME> 5432

5) Negative egress (should be blocked):
   tcping -t 3 example.com 80
EOF

# === [M] INDEX & ARCHIVE ===
INDEX="${BASE_DIR}/INDEX.txt"
{
  echo "K8s Audit — context: ${CTX}"
  echo "Directory: ${BASE_DIR}"
  echo "Timestamp: ${TS}"
  echo
  echo "Contents:"
  find "${BASE_DIR}" -type f | sed "s|${BASE_DIR}/||" | sort
} > "${INDEX}"

# === [N] ONE BIG TEXT REPORT WITH ENGLISH HEADERS ===
FULL_REPORT="${BASE_DIR}/_FULL_REPORT.txt"
{
  echo "===== K8s Full Audit Report ====="
  echo "Context: ${CTX}"
  echo "Directory: ${BASE_DIR}"
  echo "Timestamp: ${TS}"
  echo
  echo "NOTE: Each section shows the relative file path followed by its content."
  echo

  # Iterate all files except the full report itself and the archive (which is created later)
  while IFS= read -r f; do
    rel="${f#${BASE_DIR}/}"
    echo "===== [${rel}] ====="
    cat "$f"
    echo
  done < <(find "${BASE_DIR}" -type f ! -name "_FULL_REPORT.txt" -print | sort)
} > "${FULL_REPORT}"

# === [O] ARCHIVE (includes _FULL_REPORT.txt) ===
ARCHIVE="${BASE_DIR}.tgz"
tar czf "${ARCHIVE}" -C "$(dirname "${BASE_DIR}")" "$(basename "${BASE_DIR}")"

echo
echo "[OK] Audit completed."
echo "Main directory: ${BASE_DIR}"
echo "Single-file report: ${FULL_REPORT}"
echo "Index: ${INDEX}"
echo "Archive: ${ARCHIVE}"
