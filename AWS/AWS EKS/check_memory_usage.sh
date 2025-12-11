# See all processes with RSS and VSZ (in KB)
cat /proc/[0-9]*/status | grep -E "VmRSS|VmSize|Name" | paste -d '\t' - - -

# Or simpler, just the biggest ones
ps aux --sort=-rss | head -20

# If ps is also missing, fall back to the proc filesystem directly:
for p in /proc/[0-9]*; do 
  if [ -f "$p/statm" ]; then 
    rss=$(( $(awk '{print $2}' $p/statm) * 4 ))
    comm=$(cat $p/comm 2>/dev/null)
    cmd=$(tr '\0' ' ' < $p/cmdline 2>/dev/null)
    printf "%8s KB  %-12s  %s\n" "$rss" "$comm" "$cmd"
  fi
done | sort -nr | head -15

# Node-level view
kubectl top pod {$POD_NAME} --containers -n {$NAMESPACE}

# Pod resource usage and limits/requests
kubectl describe pod {$POD_NAME} -n {$NAMESPACE} | grep -A 10 -B 10 Memory

# Events and OOM kills
kubectl get events -n {$NAMESPACE} --sort-by='.lastTimestamp' | grep {$APP_LABEL}