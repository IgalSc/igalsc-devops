#!/bin/bash

# Namespaces to monitor
NAMESPACES=("staging" "zone-system" "uat")

for namespace in "${NAMESPACES[@]}"; do
  echo "Creating VPAs for namespace: $namespace"
  
  # Get all deployments in the namespace
  deployments=$(kubectl get deployments -n $namespace -o jsonpath='{.items[*].metadata.name}')
  
  if [ -z "$deployments" ]; then
    echo "  No deployments found in $namespace"
    continue
  fi
  
  for deploy in $deployments; do
    vpa_name="${deploy}-vpa"
    
    # Check if VPA already exists
    if kubectl get vpa -n $namespace $vpa_name &> /dev/null; then
      echo "  VPA $vpa_name already exists, skipping"
      continue
    fi
    
    echo "  Creating VPA: $vpa_name for deployment: $deploy"
    
    cat <<EOF | kubectl apply -f -
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: ${vpa_name}
  namespace: ${namespace}
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: Deployment
    name: ${deploy}
  updatePolicy:
    updateMode: "Off"
  resourcePolicy:
    containerPolicies:
    - containerName: "*"
      minAllowed:
        cpu: 10m
        memory: 50Mi
      maxAllowed:
        cpu: 8
        memory: 16Gi
EOF
  done
  echo ""
done

echo "Done! Check VPAs with: kubectl get vpa --all-namespaces"