# 1. Install VPA via Helm
helm repo add fairwinds-stable https://charts.fairwinds.com/stable
helm repo update

helm install vpa fairwinds-stable/vpa \
  --namespace vpa \
  --create-namespace

# 2. CRITICAL: Patch the CRD to enable status subresource
kubectl patch crd verticalpodautoscalers.autoscaling.k8s.io --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/versions/0/subresources",
    "value": {"status": {}}
  }
]'

# 3. Restart VPA recommender to pick up the change
kubectl rollout restart deployment vpa-recommender -n vpa

# 4. Create VPAs for your deployments
./create-vpas.sh

# 5. Wait 5-10 minutes, then check recommendations
./view_vpa_reco.sh