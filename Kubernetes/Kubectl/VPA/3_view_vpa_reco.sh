#!/bin/bash

NAMESPACE_1="${NAMESPACE_1}"
NAMESPACE_2="${NAMESPACE_2}"
NAMESPACE_3="${NAMESPACE_3}"

# Function to convert bytes to MiB/GiB
bytes_to_human() {
  local bytes=$1
  if [ -z "$bytes" ]; then
    echo "N/A"
    return
  fi
  
  local mib=$((bytes / 1024 / 1024))
  local gib=$((mib / 1024))
  
  if [ $gib -gt 0 ]; then
    echo "${gib}Gi (${mib}Mi)"
  else
    echo "${mib}Mi"
  fi
}

# Function to convert Mi/Gi string to MiB number
resource_to_mib() {
  local resource=$1
  if [[ $resource =~ ([0-9]+)Gi ]]; then
    echo $((${BASH_REMATCH[1]} * 1024))
  elif [[ $resource =~ ([0-9]+)Mi ]]; then
    echo ${BASH_REMATCH[1]}
  elif [[ $resource =~ ([0-9]+)M ]]; then
    # M (not Mi) is MB, slightly different
    echo $((${BASH_REMATCH[1]} * 1000 / 1024))
  else
    echo "0"
  fi
}

# Function to convert millicores string to number
cpu_to_millicores() {
  local cpu=$1
  if [[ $cpu =~ ([0-9]+)m ]]; then
    echo ${BASH_REMATCH[1]}
  elif [[ $cpu =~ ^([0-9]+)$ ]]; then
    echo $((${BASH_REMATCH[1]} * 1000))
  else
    echo "0"
  fi
}

echo "Deployment Resource Analysis"
echo "============================"
echo ""

for ns in ${NAMESPACE_1} ${NAMESPACE_2} ${NAMESPACE_3} ; do
  echo "Namespace: $ns"
  echo "$(printf '=%.0s' {1..80})"
  
  deployments=$(kubectl get deployments -n $ns -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
  
  if [ -z "$deployments" ]; then
    echo "  No deployments found"
    echo ""
    continue
  fi
  
  for deploy in $deployments; do
    # Get current requests
    current_cpu=$(kubectl get deployment $deploy -n $ns -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
    current_mem=$(kubectl get deployment $deploy -n $ns -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null)
    
    # Get VPA recommendation
    vpa="${deploy}-vpa"
    vpa_cpu=$(kubectl get vpa $vpa -n $ns -o jsonpath='{.status.recommendation.containerRecommendations[0].target.cpu}' 2>/dev/null)
    vpa_mem_bytes=$(kubectl get vpa $vpa -n $ns -o jsonpath='{.status.recommendation.containerRecommendations[0].target.memory}' 2>/dev/null)
    
    # Skip if no VPA recommendation
    if [ -z "$vpa_cpu" ] && [ -z "$vpa_mem_bytes" ]; then
      continue
    fi
    
    echo ""
    echo "  📦 $deploy"
    echo "  $(printf '─%.0s' {1..78})"
    
    # CPU Analysis
    if [ -n "$vpa_cpu" ]; then
      current_cpu_m=$(cpu_to_millicores "$current_cpu")
      vpa_cpu_m=$(cpu_to_millicores "$vpa_cpu")
      
      cpu_diff=$((current_cpu_m - vpa_cpu_m))
      cpu_percent=$(awk "BEGIN {printf \"%.0f\", ($cpu_diff / $vpa_cpu_m) * 100}")
      
      echo "  CPU:"
      echo "    Current:    ${current_cpu:-not set} (${current_cpu_m}m)"
      echo "    VPA Target: $vpa_cpu"
      
      if [ $cpu_diff -gt 0 ] && [ $vpa_cpu_m -gt 0 ]; then
        if [ $cpu_percent -gt 50 ]; then
          echo "    Status:     🔴 OVER-PROVISIONED by ${cpu_diff}m (${cpu_percent}% excess)"
        elif [ $cpu_percent -gt 20 ]; then
          echo "    Status:     🟡 Over-provisioned by ${cpu_diff}m (${cpu_percent}% excess)"
        else
          echo "    Status:     ✅ Well-sized"
        fi
      elif [ $cpu_diff -lt 0 ]; then
        echo "    Status:     🔴 UNDER-PROVISIONED by $((cpu_diff * -1))m"
      fi
    fi
    
    # Memory Analysis
    if [ -n "$vpa_mem_bytes" ]; then
      vpa_mem_human=$(bytes_to_human "$vpa_mem_bytes")
      current_mem_mib=$(resource_to_mib "$current_mem")
      vpa_mem_mib=$((vpa_mem_bytes / 1024 / 1024))
      
      mem_diff=$((current_mem_mib - vpa_mem_mib))
      if [ $vpa_mem_mib -gt 0 ]; then
        mem_percent=$(awk "BEGIN {printf \"%.0f\", ($mem_diff / $vpa_mem_mib) * 100}")
      else
        mem_percent=0
      fi
      
      echo "  Memory:"
      echo "    Current:    ${current_mem:-not set} (${current_mem_mib}Mi)"
      echo "    VPA Target: $vpa_mem_human"
      
      if [ $mem_diff -gt 100 ] && [ $vpa_mem_mib -gt 0 ]; then
        if [ $mem_percent -gt 50 ]; then
          echo "    Status:     🔴 OVER-PROVISIONED by ${mem_diff}Mi (${mem_percent}% excess)"
        elif [ $mem_percent -gt 20 ]; then
          echo "    Status:     🟡 Over-provisioned by ${mem_diff}Mi (${mem_percent}% excess)"
        else
          echo "    Status:     ✅ Well-sized"
        fi
      elif [ $mem_diff -lt -100 ]; then
        echo "    Status:     🔴 UNDER-PROVISIONED by $((mem_diff * -1))Mi"
      else
        echo "    Status:     ✅ Well-sized"
      fi
    fi
  done
  
  echo ""
done

echo ""
echo "Summary:"
echo "  🔴 = Action needed (>50% difference)"
echo "  🟡 = Consider adjusting (20-50% difference)"
echo "  ✅ = Well-sized (<20% difference)"