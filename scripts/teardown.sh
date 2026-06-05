#!/bin/bash
set -e

echo "=== Deleting Ingress to prevent LB recreation ==="
kubectl delete ingress retail-app-ingress -n retail-app --ignore-not-found

echo "=== Finding and deleting ALB ==="
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

if [ "$ALB_ARN" != "None" ] && [ -n "$ALB_ARN" ]; then
  echo "Deleting ALB: $ALB_ARN"
  aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN --region us-east-1
  echo "Waiting for ALB to delete..."
  sleep 60
else
  echo "No ALB found"
fi

echo "=== Cleaning up Kubernetes security groups ==="
aws ec2 describe-security-groups \
  --region us-east-1 \
  --filters Name=vpc-id,Values=$(terraform output -raw vpc_id) \
  --query 'SecurityGroups[?starts_with(GroupName, `k8s-`)].[GroupId]' \
  --output text | xargs -I {} aws ec2 delete-security-group --group-id {} --region us-east-1

echo "=== Running terraform destroy ==="
cd terraform
terraform destroy