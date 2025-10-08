#!/bin/bash

echo "VPA Recommendations Summary"
echo "============================="
echo ""

for namespace in staging zone-system uat; do
  echo "Namespace: $namespace"
  echo "---"

  vpas=$(kubectl get vpa -n $namespace -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)

  if [ -z "$vpas" ]; then
    echo "  No VPAs found"
    echo ""
    continue
  fi

  for vpa in $vpas; do
    # Skip goldilocks VPAs if they still exist
    if [[ $vpa == goldilocks-* ]]; then
      continue
    fi

    echo "  VPA: $vpa"
    kubectl get vpa -n $namespace $vpa -o jsonpath='    Target CPU: {.status.recommendation.containerRecommendations[0].target.cpu}, Target Memory: {.status.recommendation.conta>
    echo ""
  done
done