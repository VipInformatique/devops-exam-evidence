# DevOps Exam Evidence — Infrastructure hybride (Proxmox VE + K3s)

> Preuves publiques et sanitisées pour la soutenance DevOps (RNCP36061) :
> IaC (Terraform/Ansible), CI/CD, Observabilité, Sécurité (RBAC/NP, Zero Trust) et DR (Velero).
> Traçabilité par commit, release et hashes.

---

## 📌 Contexte

Plateforme SaaS **DeviStor** déployée on-prem (Proxmox VE) avec **K3s** pour l’orchestration, **Zero Trust** au périmètre (Cloudflare Tunnel/Access), base **PostgreSQL managée (Neon)**, observabilité **Prometheus/Grafana/Loki**. Ce dépôt rassemble **les preuves** (extraits, captures, artefacts) cohérentes avec la documentation technique v1.2 et le modèle C4.
**Auteur :** Rafal Rutkowski (VIP Informatique) • **État système :** août 2025

---

## 🗂️ Structure du dépôt

```
CP1_IaC/             # Terraform/Ansible : plans, extraits de code, inventaire/idempotence
CP2_CICD/            # Workflow GitHub Actions (extraits), logs PASS, Argo CD (captures Sync/Healthy)
CP3_Observability/   # Dashboards Grafana (JSON), règles d’alerting, preuve de notification (Telegram)
Security_RBAC_NP/    # Extraits RBAC (Role/RoleBinding), NetworkPolicy (deny-all + allow*)
DR_Velero/           # Rapports de restauration 13/08 et 17/08 + logs et preuves associées
docs/                # Index GitHub Pages (table des preuves + liens)
EVIDENCE_MANIFEST.json  # Chemins, tailles, SHA256 des artefacts clés
hashes.txt              # Sommes SHA256 (générées pour vérification)
```

---

## 🎯 Objectifs & SLO/SLI (extrait)

* **Disponibilité plateforme (SLA)** : 99,9 % (30 j)
* **RPO données (PostgreSQL/Neon)** : ≤ 1 h (PITR + dump quotidien)
* **RTO appli (basculement)** : 5–15 min (marqueur horaire)
* **RPO état cluster (Velero)** : ≤ 24 h (sauvegarde quotidienne)
* **VM maîtres Proxmox** : 1 sauvegarde/jour, **test de restauration** régulier
* **Sécurité pipeline** : CI bloque si Trivy détecte CRITICAL/HIGH ; scans flake8/Bandit
* **Réseau** : aucun port entrant ; admin via **VPN/WireGuard** ; accès web public **via Cloudflare**

---

## 🔄 Sauvegarde & DR — Calendrier (extrait)

| Cible                       | Fréquence       | Rétention | Outil          | **Test**        |
| --------------------------- | --------------- | --------- | -------------- | --------------- |
| **VMs critiques (masters)** | Quotidien 01:00 | 14 j      | Proxmox Backup | **Trimestriel** |
| **État K8s (CRD+PV)**       | Quotidien 02:00 | 14 j      | Velero → R2    | **Mensuel**     |
| **DB (dump complet)**       | Quotidien 03:00 | 30 j      | CronJob → NAS  | **Mensuel**     |

**Objectifs consolidés** : RPO cluster 24 h, RTO < 1 h (restore orchestré).
**Runbook** : *Procedure\_de\_Test\_de\_Restauration* (pas-à-pas, hors de ce dépôt).

---

## ✅ DR — Preuves clés (Velero)

**A/B** restauration en environnement isolé (namespace dédié) :

| Date       | Contexte          | Backup                        | Restore                               | Objets | Résultat |
| ---------- | ----------------- | ----------------------------- | ------------------------------------- | ------ | -------- |
| 13/08/2025 | **AVANT** RBAC/NP | `pre-rbac-np-2025-08-13-1812` | `sim-restore-1823`                    | 21/21  | PASS     |
| 17/08/2025 | **APRÈS** RBAC/NP | `post-rbac-2025-08-17-124656` | `post-rbac-restore-2025-08-17-124656` | 26/26  | PASS     |

> Logs : 0 `error`, quelques `warning` attendus (ex. `kube-root-ca.crt` existe déjà).
> Interprétation : **RBAC/NP n’entravent pas** la restauration contrôlée (namespace isolé).

Détails & journaux : voir `DR_Velero/`.

---

## 🔐 Sécurité — principes (extrait)

* **Zero Trust** : exposition **uniquement** via Cloudflare Tunnel ; Argo CD protégé par **Cloudflare Access** (MFA, allowlist).
* **RBAC minimal** : SA dédiés, accès secrets limité, **Pod Security** profil *restricted*.
* **NetworkPolicy** : *deny-all* + ouvertures ciblées (ingress depuis Traefik, egress DNS + IP Neon/5432).
* **Observabilité** (Grafana/Prometheus/Alertmanager) exposée en LAN/VPN (IP dédiée, `loadBalancerSourceRanges`).

---

## 🧪 CI/CD — qualité & gates (extrait)

* **CI (GitHub Actions)** : lint/tests, SAST (flake8/Bandit), SCA/Images (**Trivy**). Build < 10 min.
* **CD (GitOps/Argo CD)** : sync, health, prune ; images épinglées par digest.
* **Blocage prod** si vulnérabilités CRITICAL/HIGH.

---

## 🔎 Comment vérifier (traçabilité)

1. **Commit snapshot** : `<SHA7>` • **Release** : `exam-YYYYMMDD`
2. **Hashes** : `hashes.txt` (SHA256) • **Manifest** : `EVIDENCE_MANIFEST.json`
3. **Pages** : `docs/` (index des preuves + liens)
4. **Preuves DR** : comparer rapports 13/08 vs 17/08 dans `DR_Velero/`

---

## 📄 Licence & confidentialité

* **Code & config** : MIT
* **Docs & images** : CC BY-NC 4.0
* Secrets et données clients **supprimés**/masqués (`***`). Artefacts fournis **à titre de preuve**.

---

## 📬 Contact

**VIP Informatique — Rafal Rutkowski**
(Repo public de preuves — usage académique / audit)
