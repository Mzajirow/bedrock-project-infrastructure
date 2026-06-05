Production-grade microservices infrastructure on AWS EKS for InnovateMart Inc.

## Architecture

![Architecture Diagram](docs/architecture.png)

## Infrastructure Components

| Component | Technology | Details |
|---|---|---|
| Cloud Provider | AWS | us-east-1 |
| Container Orchestration | Amazon EKS | v1.34 |
| Networking | Amazon VPC | 2 AZs, public & private subnets |
| Database (MySQL) | Amazon RDS | MySQL 8.0, db.t3.micro |
| Database (PostgreSQL) | Amazon RDS | PostgreSQL 16.3, db.t3.micro |
| NoSQL Database | Amazon DynamoDB | On-demand billing |
| Secret Management | AWS Secrets Manager | RDS credentials |
| Object Storage | Amazon S3 | bedrock-assets-4910 |
| Serverless | AWS Lambda | Python 3.12 |
| Observability | Amazon CloudWatch | Container + control plane logs |
| IaC | Terraform | Remote state on S3 |
| CI/CD | GitHub Actions | Plan on PR, Apply on merge |

## Prerequisites

- AWS CLI configured with admin credentials
- Terraform >= 1.6
- kubectl
- helm >= 3
- eksctl

## Repository Structure
.
├── terraform/           # All infrastructure code
│   ├── main.tf          # Provider configuration
│   ├── backend.tf       # Remote state configuration
│   ├── vpc.tf           # VPC and networking
│   ├── eks.tf           # EKS cluster and node groups
│   ├── rds.tf           # RDS instances and secrets
│   ├── dynamodb.tf      # DynamoDB tables
│   ├── iam.tf           # IAM users and roles
│   ├── s3_lambda.tf     # S3 bucket and Lambda function
│   └── outputs.tf       # Terraform outputs
├── lambda/              # Lambda function code
│   └── handler.py       # Asset processor function
├── scripts/             # Utility scripts
│   └── resume.sh        # Post-destroy spinup script
├── grading.json         # Terraform outputs for grading
└── .github/
└── workflows/
└── terraform.yml # CI/CD pipeline

## Deployment Guide

### Initial Setup

1. Bootstrap remote state S3 bucket (one time only):
```bash
aws s3api create-bucket \
  --bucket project-bedrock-tfstate-4910 \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket project-bedrock-tfstate-4910 \
  --versioning-configuration Status=Enabled
```

2. Deploy infrastructure:
```bash
cd terraform
terraform init
terraform apply
```

3. Configure kubectl:
```bash
aws eks update-kubeconfig --region us-east-1 --name project-bedrock-cluster
```

4. Install AWS Load Balancer Controller:
```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

eksctl create iamserviceaccount \
  --cluster=project-bedrock-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --override-existing-serviceaccounts \
  --region us-east-1

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=project-bedrock-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### Deploying the Application

See the [Application Repository](https://github.com/Mzajirow/retail-store-app) for deployment instructions.

### CI/CD Pipeline

| Trigger | Action |
|---|---|
| Pull Request to main | Runs `terraform plan` and posts output as PR comment |
| Merge to main | Runs `terraform apply -auto-approve` |

**Required GitHub Secrets:**
- `AWS_ACCESS_KEY_ID` — Admin IAM access key
- `AWS_SECRET_ACCESS_KEY` — Admin IAM secret key

### Tearing Down

```bash
cd terraform
terraform destroy
```

> ⚠️ Note: Delete the AWS Load Balancer manually before destroying to avoid VPC dependency errors:
> ```bash
> aws elbv2 describe-load-balancers --region us-east-1 --query 'LoadBalancers[*].[LoadBalancerArn]' --output text
> aws elbv2 delete-load-balancer --load-balancer-arn <ARN> --region us-east-1
> ```

### Resuming After Destroy

After `terraform apply` completes:
```bash
./scripts/resume.sh
```

## Developer Access

The `bedrock-dev-view` IAM user has read-only access to:
- AWS Console (ReadOnlyAccess policy)
- Kubernetes cluster (view ClusterRole)

Verification:
```bash
# Should succeed
kubectl get pods -n retail-app --context bedrock-dev-view

# Should fail
kubectl delete pod -n retail-app --context bedrock-dev-view <pod-name>
```

## Observability

Logs are available in CloudWatch under:
- `/aws/eks/project-bedrock-cluster/cluster` — Control plane logs
- `/aws/containerinsights/project-bedrock-cluster/application` — Application logs
- `/aws/lambda/bedrock-asset-processor` — Lambda function logs

## Resource Tagging

All resources are tagged with:
Project: karatu-2025-capstone