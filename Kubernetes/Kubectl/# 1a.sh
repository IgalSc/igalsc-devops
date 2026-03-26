# 1a
eksctl create nodegroup \
  --cluster eks-es3-prod \
  --name t3a-1a \
  --managed \
  --nodes 2 --nodes-min 2 --nodes-max 5 \
  --node-type t3a.large \
  --subnet-ids subnet-0ffc09ee75ff4e85f,subnet-03b3eab1d3b982cf8,subnet-0f11cda0e78582a71

# 1b
eksctl create nodegroup \
  --cluster eks-es3-prod \
  --name t3a-1b \
  --managed \
  --nodes 2 --nodes-min 2 --nodes-max 5 \
  --node-type t3a.large \
  --subnet-ids subnet-0ffc09ee75ff4e85f,subnet-03b3eab1d3b982cf8,subnet-0f11cda0e78582a71