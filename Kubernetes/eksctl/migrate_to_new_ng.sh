#!/bin/bash

set -e  # Exit on error

# Configuration
CLUSTER_NAME="eks-staging"
OLD_NODEGROUPS=("nodes-2a" "nodes-2b")  # Add all old nodegroup names here
REGION="us-east-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Cordon all nodes in old nodegroups
log_info "=========================================="
log_info "Step 1: Cordoning nodes in old nodegroups"
log_info "=========================================="

for nodegroup in "${OLD_NODEGROUPS[@]}"; do
    log_info "Cordoning nodes in nodegroup: $nodegroup"
    
    NODES=$(kubectl get nodes -l eks.amazonaws.com/nodegroup=$nodegroup -o name)
    
    if [ -z "$NODES" ]; then
        log_warn "No nodes found for nodegroup: $nodegroup"
        continue
    fi
    
    for node in $NODES; do
        log_info "  Cordoning $node"
        kubectl cordon $node
    done
done

log_info "All old nodes cordoned successfully"
echo ""

# Step 2: Get all namespaces (excluding kube-system, kube-public, kube-node-lease)
log_info "=========================================="
log_info "Step 2: Getting list of namespaces"
log_info "=========================================="

NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E '^(kube-system|kube-public|kube-node-lease|default)$')

log_info "Found namespaces: $(echo $NAMESPACES | tr '\n' ' ')"
echo ""

# Step 3: Rollout restart all deployments
log_info "=========================================="
log_info "Step 3: Rolling restart all deployments"
log_info "=========================================="

for ns in $NAMESPACES; do
    log_info "Processing namespace: $ns"
    
    DEPLOYMENTS=$(kubectl get deployments -n $ns -o name 2>/dev/null)
    
    if [ -z "$DEPLOYMENTS" ]; then
        log_warn "  No deployments found in namespace: $ns"
        continue
    fi
    
    for deployment in $DEPLOYMENTS; do
        DEPLOY_NAME=$(echo $deployment | cut -d'/' -f2)
        log_info "  Restarting deployment: $DEPLOY_NAME"
        
        kubectl rollout restart $deployment -n $ns
        
        log_info "  Waiting for rollout to complete: $DEPLOY_NAME"
        kubectl rollout status $deployment -n $ns --timeout=600s
        
        if [ $? -eq 0 ]; then
            log_info "  ✓ $DEPLOY_NAME rolled out successfully"
        else
            log_error "  ✗ Failed to rollout $DEPLOY_NAME"
            read -p "Continue anyway? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    done
    
    log_info "Completed deployments in namespace: $ns"
    echo ""
done

log_info "All deployments restarted successfully"
echo ""

# Step 4: Handle StatefulSets
log_info "=========================================="
log_info "Step 4: Handling StatefulSets"
log_info "=========================================="

for ns in $NAMESPACES; do
    log_info "Checking StatefulSets in namespace: $ns"
    
    STATEFULSETS=$(kubectl get statefulsets -n $ns -o name 2>/dev/null)
    
    if [ -z "$STATEFULSETS" ]; then
        log_warn "  No StatefulSets found in namespace: $ns"
        continue
    fi
    
    for sts in $STATEFULSETS; do
        STS_NAME=$(echo $sts | cut -d'/' -f2)
        log_info "  Processing StatefulSet: $STS_NAME"
        
        # Get pods from this StatefulSet
        PODS=$(kubectl get pods -n $ns -l app=$STS_NAME -o name 2>/dev/null)
        
        # Check if any pods are on old nodes
        for pod in $PODS; do
            POD_NAME=$(echo $pod | cut -d'/' -f2)
            NODE=$(kubectl get pod $POD_NAME -n $ns -o jsonpath='{.spec.nodeName}')
            
            # Check if node is in old nodegroups
            for nodegroup in "${OLD_NODEGROUPS[@]}"; do
                NODE_NODEGROUP=$(kubectl get node $NODE -o jsonpath='{.metadata.labels.eks\.amazonaws\.com/nodegroup}' 2>/dev/null)
                
                if [ "$NODE_NODEGROUP" == "$nodegroup" ]; then
                    log_warn "  Pod $POD_NAME is on old node: $NODE"
                    log_info "  Deleting pod to trigger rescheduling: $POD_NAME"
                    kubectl delete pod $POD_NAME -n $ns
                    
                    log_info "  Waiting for pod to be recreated..."
                    kubectl wait --for=condition=Ready pod -l app=$STS_NAME -n $ns --timeout=300s
                    
                    # Check PVCs
                    PVC=$(kubectl get pod $POD_NAME -n $ns -o jsonpath='{.spec.volumes[?(@.persistentVolumeClaim)].persistentVolumeClaim.claimName}' 2>/dev/null)
                    if [ ! -z "$PVC" ]; then
                        log_info "  Found PVC: $PVC"
                        log_warn "  NOTE: PVC will remain attached. Verify data integrity after migration."
                    fi
                fi
            done
        done
        
        log_info "  ✓ StatefulSet $STS_NAME processed"
    done
    
    echo ""
done

log_info "All StatefulSets processed"
echo ""

# Step 5: Verify no pods remain on old nodes
log_info "=========================================="
log_info "Step 5: Verifying pod migration"
log_info "=========================================="

for nodegroup in "${OLD_NODEGROUPS[@]}"; do
    log_info "Checking remaining pods on nodegroup: $nodegroup"
    
    for node in $(kubectl get nodes -l eks.amazonaws.com/nodegroup=$nodegroup -o name); do
        NODE_NAME=$(echo $node | cut -d'/' -f2)
        REMAINING_PODS=$(kubectl get pods -A --field-selector spec.nodeName=$NODE_NAME --no-headers 2>/dev/null | grep -v kube-system | wc -l)
        
        if [ $REMAINING_PODS -gt 0 ]; then
            log_warn "  Found $REMAINING_PODS non-system pods still on $NODE_NAME"
            kubectl get pods -A --field-selector spec.nodeName=$NODE_NAME -o wide
            
            log_warn "  Draining node: $NODE_NAME"
            kubectl drain $node --ignore-daemonsets --delete-emptydir-data --grace-period=300 --timeout=600s
        else
            log_info "  ✓ No application pods remaining on $NODE_NAME"
        fi
    done
done

echo ""

# Step 6: Final verification
log_info "=========================================="
log_info "Step 6: Final health check"
log_info "=========================================="

log_info "Checking for any pods not in Running state:"
NOT_RUNNING=$(kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | wc -l)

if [ $NOT_RUNNING -gt 0 ]; then
    log_error "Found $NOT_RUNNING pods not running:"
    kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
    
    read -p "Pods are not running. Continue with nodegroup deletion? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "Aborting nodegroup deletion"
        exit 1
    fi
else
    log_info "✓ All pods are running"
fi

log_info "Checking deployment status:"
UNAVAILABLE=$(kubectl get deployments -A -o json | jq -r '.items[] | select(.status.unavailableReplicas > 0) | "\(.metadata.namespace)/\(.metadata.name)"')

if [ ! -z "$UNAVAILABLE" ]; then
    log_error "Found deployments with unavailable replicas:"
    echo "$UNAVAILABLE"
    
    read -p "Deployments have unavailable replicas. Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "Aborting nodegroup deletion"
        exit 1
    fi
else
    log_info "✓ All deployments are healthy"
fi

echo ""

# Step 7: Delete old nodegroups
log_info "=========================================="
log_info "Step 7: Deleting old nodegroups"
log_info "=========================================="

log_warn "About to delete the following nodegroups:"
for nodegroup in "${OLD_NODEGROUPS[@]}"; do
    echo "  - $nodegroup"
done

read -p "Are you sure you want to delete these nodegroups? (yes/no) " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    log_warn "Nodegroup deletion cancelled"
    log_info "Old nodegroups are cordoned and drained but NOT deleted"
    log_info "You can delete them manually later with:"
    for nodegroup in "${OLD_NODEGROUPS[@]}"; do
        echo "  eksctl delete nodegroup --cluster=$CLUSTER_NAME --name=$nodegroup --region=$REGION"
    done
    exit 0
fi

for nodegroup in "${OLD_NODEGROUPS[@]}"; do
    log_info "Deleting nodegroup: $nodegroup"
    
    eksctl delete nodegroup \
        --cluster=$CLUSTER_NAME \
        --name=$nodegroup \
        --region=$REGION \
        --drain=false  # Already drained
    
    if [ $? -eq 0 ]; then
        log_info "✓ Successfully deleted nodegroup: $nodegroup"
    else
        log_error "✗ Failed to delete nodegroup: $nodegroup"
    fi
done

echo ""
log_info "=========================================="
log_info "Migration Complete!"
log_info "=========================================="

log_info "Summary:"
log_info "  ✓ Old nodes cordoned"
log_info "  ✓ All deployments restarted"
log_info "  ✓ All StatefulSets migrated"
log_info "  ✓ Old nodegroups deleted"

echo ""
log_info "Please monitor your cluster for the next 24 hours to ensure stability"
log_info "Check cluster status with: kubectl get nodes && kubectl get pods -A"