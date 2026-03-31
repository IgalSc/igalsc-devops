echo -e "DEPLOYMENT\tCONTAINER\tREQ_CPU\tREQ_MEM\tLIM_CPU\tLIM_MEM"
kubectl get deploy -n prod -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.template.spec.containers[*]}{.name}{"\t"}{.resources.requests.cpu}{"\t"}{.resources.requests.memory}{"\t"}{.resources.limits.cpu}{"\t"}{.resources.limits.memory}{"\n"}{end}{end}'
