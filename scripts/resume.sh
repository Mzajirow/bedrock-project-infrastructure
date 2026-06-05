#!/bin/bash

set -e

echo "=== Step 1: Updating kubeconfig ==="

aws eks update-kubeconfig \
  --region us-east-1 \
  --name project-bedrock-cluster

echo "=== Step 2: Installing LB Controller ==="

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

eksctl create iamserviceaccount \
  --cluster=project-bedrock-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --override-existing-serviceaccounts \
  --region us-east-1

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=project-bedrock-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

echo "=== Step 3: Getting RDS credentials ==="

MYSQL_HOST=$(aws rds describe-db-instances \
  --db-instance-identifier bedrock-mysql \
  --region us-east-1 \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

POSTGRES_HOST=$(aws rds describe-db-instances \
  --db-instance-identifier bedrock-postgres \
  --region us-east-1 \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

MYSQL_PASS=$(aws secretsmanager get-secret-value \
  --secret-id project-bedrock/mysql \
  --region us-east-1 \
  --query SecretString \
  --output text | grep -o '"password":"[^"]*"' | cut -d'"' -f4)

POSTGRES_PASS=$(aws secretsmanager get-secret-value \
  --secret-id project-bedrock/postgres \
  --region us-east-1 \
  --query SecretString \
  --output text | grep -o '"password":"[^"]*"' | cut -d'"' -f4)

echo "=== Step 4: Deploying application ==="

kubectl create namespace retail-app \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -k k8s/overlays/aws/

kubectl patch secret catalog-db \
  -n retail-app \
  --type='json' \
  -p="[{\"op\": \"replace\", \"path\": \"/data/RETAIL_CATALOG_PERSISTENCE_PASSWORD\", \"value\": \"$(echo -n "$MYSQL_PASS" | base64)\"}]"

kubectl patch secret orders-db \
  -n retail-app \
  --type='json' \
  -p="[{\"op\": \"replace\", \"path\": \"/data/RETAIL_ORDERS_PERSISTENCE_PASSWORD\", \"value\": \"$(echo -n "$POSTGRES_PASS" | base64)\"}]"

echo "=== Step 5: Applying Ingress and RBAC ==="

kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/rbac.yaml

echo "=== Done! Waiting for pods ==="

kubectl get pods -n retail-app
