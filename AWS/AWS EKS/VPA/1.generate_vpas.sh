#!/bin/bash
# Script to discover workloads and generate Vertical Pod Autoscaler (VPA) manifests
# Prerequisites: kubectl, jq, helm
# Install VPA CRDs and controller if not already installed
helm repo add fairwinds-stable https://charts.fairwinds.com/stable
helm repo update
echo "VPA Helm chart repository added."
sleep 5
# Discover all workloads and their current resource configuration:
{ echo -e "NAMESPACE\tOWNER\tPOD\tCONTAINER\tCPU_REQ\tMEM_REQ\tCPU_LIM\tMEM_LIM";   kubectl get pod --all-namespaces -o json |   jq -r '
    .items[]
    | . as $pod
    | .spec.containers[]
    | {
        namespace: $pod.metadata.namespace,
        owner: (
          ($pod.metadata.ownerReferences[]?
           | select(.controller==true)
           | .kind + "/" + .name
          ) // "none"
        ),
        pod: $pod.metadata.name,
        container: .name,
        cpu_req: (.resources.requests.cpu // "-"),
        mem_req: (.resources.requests.memory // "-"),
        cpu_lim: (.resources.limits.cpu // "-"),
        mem_lim: (.resources.limits.memory // "-")
      }
    | [.namespace,.owner,.pod,.container,.cpu_req,.mem_req,.cpu_lim,.mem_lim] | @tsv
  ' | sort -k1,2; } | awk 'BEGIN{FS=OFS="\t"}
NR==1 {printf "\033[1;36m%-20s %-40s %-50s %-25s %-12s %-15s %-12s %-15s\033[0m\n", $1,$2,$3,$4,$5,$6,$7,$8; next}
{printf "%-20s %-40s %-50s %-25s %-12s %-15s %-12s %-15s\n", $1,$2,$3,$4,$5,$6,$7,$8}'
# Save discovered workloads to JSON for further processing
kubectl get pod --all-namespaces -o json | jq -r '
  .items[]
  | . as $pod
  | .spec.containers[]
  | {
      namespace: $pod.metadata.namespace,
      owner_kind: (($pod.metadata.ownerReferences[]? | select(.controller==true) | .kind) // "none"),
      owner_name: (($pod.metadata.ownerReferences[]? | select(.controller==true) | .name) // "none"),
      container: .name,
      cpu_req: (.resources.requests.cpu // "-"),
      mem_req: (.resources.requests.memory // "-"),
      cpu_lim: (.resources.limits.cpu // "-"),
      mem_lim: (.resources.limits.memory // "-")
    }
' > workload-discovery.json

echo "Discovered workloads saved to workload-discovery.json"
sleep 5
# Generate VPA manifests based on discovered workloads
cat > generate-vpas-from-discovery.sh <<'SCRIPT'
#!/bin/bash
# Namespaces to EXCLUDE from VPA creation
# Add any namespaces you don't want VPAs for (space-separated)
EXCLUDE_NAMESPACES="kube-system kube-public kube-node-lease"
# Convert to regex pattern
EXCLUDE_PATTERN=$(echo "$EXCLUDE_NAMESPACES" | tr ' ' '|')
echo "# Auto-generated VPA manifests"
echo "# Generated on: $(date)"
echo "# Excluded namespaces: $EXCLUDE_NAMESPACES"
echo ""
# Process Deployments (owner is ReplicaSet, need to find parent Deployment)
kubectl get deployments -A -o json | jq -r --arg exclude "$EXCLUDE_PATTERN" '
  .items[]
  | select(.metadata.namespace | test($exclude) | not)
  | .metadata as $meta
  | .spec.template.spec.containers as $containers
  | {
      namespace: $meta.namespace,
      name: $meta.name,
      containers: [
        $containers[]
        | {
            name: .name,
            cpu_req: (.resources.requests.cpu // "10m"),
            mem_req: (.resources.requests.memory // "50Mi"),
            cpu_lim: (.resources.limits.cpu // "4"),
            mem_lim: (.resources.limits.memory // "8Gi")
          }
      ]
    }
  | "---
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: \(.name)
  namespace: \(.namespace)
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: \(.name)
  updatePolicy:
    updateMode: \"Off\"
  resourcePolicy:
    containerPolicies:\(.containers | map("
      - containerName: \"\(.name)\"
        minAllowed:
          cpu: 10m
          memory: 50Mi
        maxAllowed:
          cpu: 4
          memory: 8Gi") | join(""))"'

# Process StatefulSets
kubectl get statefulsets -A -o json | jq -r --arg exclude "$EXCLUDE_PATTERN" '
  .items[]
  | select(.metadata.namespace | test($exclude) | not)
  | .metadata as $meta
  | .spec.template.spec.containers as $containers
  | {
      namespace: $meta.namespace,
      name: $meta.name,
      containers: [
        $containers[]
        | {
            name: .name,
            cpu_req: (.resources.requests.cpu // "10m"),
            mem_req: (.resources.requests.memory // "50Mi"),
            cpu_lim: (.resources.limits.cpu // "4"),
            mem_lim: (.resources.limits.memory // "8Gi")
          }
      ]
    }
  | "---
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: \(.name)
  namespace: \(.namespace)
spec:
  targetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: \(.name)
  updatePolicy:
    updateMode: \"Off\"
  resourcePolicy:
    containerPolicies:\(.containers | map("
      - containerName: \"\(.name)\"
        minAllowed:
          cpu: 10m
          memory: 50Mi
        maxAllowed:
          cpu: 4
          memory: 8Gi") | join(""))"'

# Process DaemonSets
kubectl get daemonsets -A -o json | jq -r --arg exclude "$EXCLUDE_PATTERN" '
  .items[]
  | select(.metadata.namespace | test($exclude) | not)
  | .metadata as $meta
  | .spec.template.spec.containers as $containers
  | {
      namespace: $meta.namespace,
      name: $meta.name,
      containers: [
        $containers[]
        | {
            name: .name,
            cpu_req: (.resources.requests.cpu // "10m"),
            mem_req: (.resources.requests.memory // "50Mi"),
            cpu_lim: (.resources.limits.cpu // "4"),
            mem_lim: (.resources.limits.memory // "8Gi")
          }
      ]
    }
  | "---
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: \(.name)
  namespace: \(.namespace)
spec:
  targetRef:
    apiVersion: apps/v1
    kind: DaemonSet
    name: \(.name)
  updatePolicy:
    updateMode: \"Off\"
  resourcePolicy:
    containerPolicies:\(.containers | map("
      - containerName: \"\(.name)\"
        minAllowed:
          cpu: 10m
          memory: 50Mi
        maxAllowed:
          cpu: 4
          memory: 8Gi") | join(""))"'
SCRIPT

chmod +x generate-vpas-from-discovery.sh
# Optionally, modify excluded namespaces
sed -i 's/EXCLUDE_NAMESPACES="kube-system kube-public kube-node-lease"/EXCLUDE_NAMESPACES="kube-system kube-public kube-node-lease cert-manager ingress-nginx"/' generate-vpas-from-discovery.sh
# Generate VPAs and save to vpas.yaml
./generate-vpas-from-discovery.sh > vpas.yaml
# Review what will be created:
# Show summary of VPAs to be created
echo "=== VPAs to be created ==="
grep -E "^  name:|^  namespace:|kind: Deployment|kind: StatefulSet|kind: DaemonSet" vpas.yaml |   paste - - - |   awk '{print $2, $4, $6}' |   column -t
# Count by type
echo ""
echo "=== Summary ==="
echo "Deployments:  $(grep -c "kind: Deployment" vpas.yaml)"
echo "StatefulSets: $(grep -c "kind: StatefulSet" vpas.yaml)"
echo "DaemonSets:   $(grep -c "kind: DaemonSet" vpas.yaml)"
echo "Total VPAs:   $(grep -c "kind: VerticalPodAutoscaler" vpas.yaml)"
# Apply the generated VPAs
kubectl apply -f vpas.yaml
# Verify VPAs
kubectl get vpa -A
# Show detailed VPA status
kubectl get vpa -A -o custom-columns="\
    NAMESPACE:.metadata.namespace,\
    NAME:.metadata.name,\
    TARGET:.spec.targetRef.kind,\
    MODE:.spec.updatePolicy.updateMode,\
    PROVIDED:.status.conditions[?(@.type=='RecommendationProvided')].status"
# Check for Prometheus pods to ensure monitoring is in place 
kubectl get pods -A | grep -i prometheus
export PROM_NS="kubecost"
# Create the ConfigMap for VPA metrics
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ksm-vpa-config
  namespace: ${PROM_NS}
data:
  custom-resource-state.yaml: |
    kind: CustomResourceStateMetrics
    spec:
      resources:
        - groupVersionKind:
            group: autoscaling.k8s.io
            version: v1
            kind: VerticalPodAutoscaler
          labelsFromPath:
            verticalpodautoscaler: [metadata, name]
            namespace: [metadata, namespace]
            target_api_version: [spec, targetRef, apiVersion]
            target_kind: [spec, targetRef, kind]
            target_name: [spec, targetRef, name]
          metrics:
            - name: vpa_containerrecommendations_target
              help: "VPA target CPU recommendation in cores"
              each:
                type: Gauge
                gauge:
                  path: [status, recommendation, containerRecommendations]
                  valueFrom: [target, cpu]
                  labelsFromPath:
                    container: [containerName]
              commonLabels:
                resource: "cpu"
            - name: vpa_containerrecommendations_target
              help: "VPA target memory recommendation in bytes"
              each:
                type: Gauge
                gauge:
                  path: [status, recommendation, containerRecommendations]
                  valueFrom: [target, memory]
                  labelsFromPath:
                    container: [containerName]
              commonLabels:
                resource: "memory"
            - name: vpa_containerrecommendations_lowerbound
              help: "VPA lower bound CPU recommendation"
              each:
                type: Gauge
                gauge:
                  path: [status, recommendation, containerRecommendations]
                  valueFrom: [lowerBound, cpu]
                  labelsFromPath:
                    container: [containerName]
              commonLabels:
                resource: "cpu"
            - name: vpa_containerrecommendations_lowerbound
              help: "VPA lower bound memory recommendation"
              each:
                type: Gauge
                gauge:
                  path: [status, recommendation, containerRecommendations]
                  valueFrom: [lowerBound, memory]
                  labelsFromPath:
                    container: [containerName]
              commonLabels:
                resource: "memory"
            - name: vpa_containerrecommendations_upperbound
              help: "VPA upper bound CPU recommendation"
              each:
                type: Gauge
                gauge:
                  path: [status, recommendation, containerRecommendations]
                  valueFrom: [upperBound, cpu]
                  labelsFromPath:
                    container: [containerName]
              commonLabels:
                resource: "cpu"
            - name: vpa_containerrecommendations_upperbound
              help: "VPA upper bound memory recommendation"
              each:
                type: Gauge
                gauge:
                  path: [status, recommendation, containerRecommendations]
                  valueFrom: [upperBound, memory]
                  labelsFromPath:
                    container: [containerName]
              commonLabels:
                resource: "memory"
EOF
# Create RBAC
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-state-metrics-vpa
  namespace: ${PROM_NS}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kube-state-metrics-vpa
rules:
  - apiGroups: ["autoscaling.k8s.io"]
    resources: ["verticalpodautoscalers"]
    verbs: ["list", "watch"]
  - apiGroups: ["apiextensions.k8s.io"]
    resources: ["customresourcedefinitions"]
    verbs: ["list", "watch"]    
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kube-state-metrics-vpa
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kube-state-metrics-vpa
subjects:
  - kind: ServiceAccount
    name: kube-state-metrics-vpa
    namespace: ${PROM_NS}
EOF
# Deploy the VPA metrics exporter
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kube-state-metrics-vpa
  namespace: ${PROM_NS}
  labels:
    app.kubernetes.io/name: kube-state-metrics-vpa
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: kube-state-metrics-vpa
  template:
    metadata:
      labels:
        app.kubernetes.io/name: kube-state-metrics-vpa
    spec:
      serviceAccountName: kube-state-metrics-vpa
      containers:
        - name: kube-state-metrics
          image: registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.13.0
          args:
            - --port=8080
            - --telemetry-port=8081
            - --custom-resource-state-config-file=/config/custom-resource-state.yaml
            - --custom-resource-state-only
          ports:
            - name: http-metrics
              containerPort: 8080
            - name: telemetry
              containerPort: 8081
          volumeMounts:
            - name: config
              mountPath: /config
      volumes:
        - name: config
          configMap:
            name: ksm-vpa-config
---
apiVersion: v1
kind: Service
metadata:
  name: kube-state-metrics-vpa
  namespace: ${PROM_NS}
  labels:
    app.kubernetes.io/name: kube-state-metrics-vpa
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
spec:
  ports:
    - name: http-metrics
      port: 8080
      targetPort: http-metrics
  selector:
    app.kubernetes.io/name: kube-state-metrics-vpa
EOF
# Verify the exporter is running
# Check pod status
kubectl get pods -n ${PROM_NS} -l app.kubernetes.io/name=kube-state-metrics-vpa

# Check logs for errors
kubectl logs -n ${PROM_NS} -l app.kubernetes.io/name=kube-state-metrics-vpa

# Test metrics endpoint
kubectl port-forward -n ${PROM_NS} svc/kube-state-metrics-vpa 8080:8080 &
sleep 2
curl -s localhost:8080/metrics | grep -c kube_customresource_vpa
kill %1
echo "Going to configure Prometheus to scrape VPA metrics..."
sleep 5
# Configure Prometheus Scraping
# Kubecost's Prometheus has metric allowlists that block VPA metrics
# We need to add a dedicated scrape job

# Backup current prometheus config
kubectl get configmap -n ${PROM_NS} kubecost-prometheus-server -o yaml > prom-config-backup.yaml

# Export current prometheus.yml
kubectl get configmap -n ${PROM_NS} kubecost-prometheus-server -o jsonpath='{.data.prometheus\.yml}' > prometheus-original.yml

# Find where to insert (after the prometheus job, before bearer_token_file line)
INSERT_LINE=$(grep -n "^- bearer_token_file:" prometheus-original.yml | head -1 | cut -d: -f1)
INSERT_LINE=$((INSERT_LINE - 1))

# Create new config with VPA job inserted
head -n ${INSERT_LINE} prometheus-original.yml > prometheus-fixed.yml
cat >> prometheus-fixed.yml << 'PROMEOF'
- job_name: kube-state-metrics-vpa
  static_configs:
  - targets:
    - kube-state-metrics-vpa.kubecost.svc:8080
PROMEOF
tail -n +$((INSERT_LINE + 1)) prometheus-original.yml >> prometheus-fixed.yml

# Update the configmap
kubectl create configmap kubecost-prometheus-server \
  -n ${PROM_NS} \
  --from-file=prometheus.yml=prometheus-fixed.yml \
  --from-file=alerting_rules.yml=<(kubectl get configmap -n ${PROM_NS} kubecost-prometheus-server -o jsonpath='{.data.alerting_rules\.yml}') \
  --from-file=recording_rules.yml=<(kubectl get configmap -n ${PROM_NS} kubecost-prometheus-server -o jsonpath='{.data.recording_rules\.yml}') \
  --from-file=alerts=<(kubectl get configmap -n ${PROM_NS} kubecost-prometheus-server -o jsonpath='{.data.alerts}') \
  --from-file=rules=<(kubectl get configmap -n ${PROM_NS} kubecost-prometheus-server -o jsonpath='{.data.rules}') \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart Prometheus to pick up new config
kubectl rollout restart -n ${PROM_NS} deploy/kubecost-prometheus-server
kubectl rollout status -n ${PROM_NS} deploy/kubecost-prometheus-server

# Wait for scrape cycle
echo "Waiting 60s for Prometheus to scrape VPA metrics..."
sleep 60
# Verify VPA target is being scraped
kubectl exec -n ${PROM_NS} deploy/kubecost-prometheus-server -- \
  wget -qO- 'http://localhost:9090/api/v1/targets' 2>/dev/null | \
  jq '.data.activeTargets[] | select(.labels.job == "kube-state-metrics-vpa") | {job: .labels.job, health: .health}'

# Verify metrics are in Prometheus (should return a number > 0)
VPA_COUNT=$(kubectl exec -n ${PROM_NS} deploy/kubecost-prometheus-server -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=count(kube_customresource_vpa_containerrecommendations_target)' 2>/dev/null | \
  jq -r '.data.result[0].value[1]')

echo "VPA metrics in Prometheus: ${VPA_COUNT}"

if [ "$VPA_COUNT" != "null" ] && [ "$VPA_COUNT" -gt 0 ]; then
  echo "✅ VPA metrics are being collected successfully!"
else
  echo "❌ VPA metrics not found. Check Prometheus logs and scrape config."
fi
# Import the Dashboard
# Open Grafana
# Go to Dashboards → Import
# Upload the vpa-recommendations-dashboard-v4.json file
# Select your Prometheus datasource
# Click Import