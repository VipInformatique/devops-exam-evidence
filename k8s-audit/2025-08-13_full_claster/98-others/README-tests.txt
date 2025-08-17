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
