Kubernetes EKS Terraform Deployment with Helm Applications and Sample App
Overview

This repository contains Terraform code to provision a fully functional AWS EKS cluster with:

VPC, subnets, and networking resources

EKS cluster with managed node groups

IAM roles using IRSA for Helm-managed applications

AWS EFS for persistent storage

AWS Load Balancer Controller (ALB) for ingress routing

It also deploys the following Helm applications:

EFS CSI Driver

AWS Load Balancer Controller (ALB)

ArgoCD for GitOps

Prometheus for monitoring

Additionally, a sample application (app1) with backend and frontend is deployed using Kubernetes manifests.

A cleanup script is included to safely remove cluster resources before running terraform destroy.

Prerequisites

Terraform >= 1.5

AWS CLI configured with proper credentials

kubectl >= 1.26

Helm >= 3

jq (optional, used in cleanup script)

Deployment Steps

Initialize Terraform

terraform init
terraform validate
terraform plan

Apply Terraform to provision infrastructure

terraform apply --auto-approve

This will create the VPC, EKS cluster, node groups, IAM roles, and deploy Helm applications (EFS CSI Driver, ALB Controller, ArgoCD, Prometheus).

Configure AWS CLI

aws eks update-kubeconfig --region us-west-2 --name my-eks-cluster

Replace us-west-2 with your AWS region. This command configures your local kubectl to connect to the EKS cluster.

Verify cluster is ready

kubectl get nodes
Deploy Sample Application (app1)

All resources are in the dev namespace.

Create namespace

kubectl apply -f namespace.yaml

Create ServiceAccount and RBAC

kubectl apply -f sa_role.yaml

Deploy backend and frontend services

kubectl apply -f service.yaml
kubectl apply -f backend.deploy
kubectl apply -f frontend.deploy

Apply Ingress

kubectl apply -f ingress.yaml

⚠️ Make sure to update the alb.ingress.kubernetes.io/certificate-arn annotation in ingress.yaml with your ACM certificate ARN.

Cleanup (Optional)

A cleanup.sh script is included to remove:

Namespaces (dev, argocd, monitoring)

Helm releases (ALB Controller, EFS CSI Driver, ArgoCD, Prometheus)

Orphaned AWS resources (ALBs, target groups, ENIs)

Run:

bash cleanup.sh

After cleanup, destroy Terraform-managed infrastructure:

terraform destroy --auto-approve

If subnets or resources fail to delete, run:

terraform destroy --auto-approve -target=module.eks
terraform destroy --auto-approve
Notes

ALB Ingress: Provides host-based routing for frontend.hex.com and backend.hex.com. Ensure DNS points to the ALB.

RBAC: All pods in dev namespace use the dev-sa service account with limited permissions.

EFS: Configured using EFS CSI Driver for persistent storage (if used in workloads).

Monitoring & GitOps: Prometheus monitors cluster metrics; ArgoCD manages GitOps workflows.

References

Terraform AWS EKS Module

AWS EFS CSI Driver

AWS Load Balancer Controller

ArgoCD Helm Chart

Prometheus Helm Chart























Kubernetes EKS Terraform Deployment with Helm Applications and Sample App
Overview

This repository contains Terraform code to provision a fully functional AWS EKS cluster with:

VPC, subnets, and networking resources

EKS cluster with managed node groups

IAM roles using IRSA for Helm-managed applications

AWS EFS for persistent storage

AWS Load Balancer Controller for ingress routing

Helm applications:

EFS CSI Driver

AWS Load Balancer Controller (ALB)

ArgoCD for GitOps

Prometheus for monitoring

Additionally, a sample application (app1) with backend and frontend is deployed using Kubernetes manifests.

A cleanup script is included to safely remove cluster resources before running terraform destroy.


Prerequisites

Terraform >= 1.5

AWS CLI configured with proper credentials

kubectl >= 1.26

Helm >= 3

jq (optional, used in cleanup script)


Deployment Steps

terraform init
terraform validate
terraform plan
terraform apply --auto-approve
This will create the VPC, EKS cluster, node groups, IAM roles, and deploy Helm applications (EFS CSI Driver, ALB Controller, ArgoCD, Prometheus).

Configure AWS CLI
run the command aws eks update-kubeconfig --region us-west-2 --name my-eks-cluster   # replace the AWS region us-west-2, with your own AWS region
This command uses the AWS CLI to configure your local kubectl so it can connect to your Amazon EKS cluster.

Verify cluster is ready by running the following command:
kubectl get nodes

Deploy Sample Application (app1)

All resources are in the dev namespace.

Create namespace

kubectl apply -f namespace.yaml

Create ServiceAccount and RBAC

kubectl apply -f sa_role.yaml

Deploy backend and frontend services

kubectl apply -f service.yaml
kubectl apply -f backend.deploy
kubectl apply -f frontend.deploy

Apply Ingress

kubectl apply -f ingress.yaml

Make sure to update the alb.ingress.kubernetes.io/certificate-arn annotation in ingress.yaml with your ACM certificate ARN.

OPTIONAL
Below are steps to destroy the entire setup if needed

Cleanup

A cleanup.sh script is included to remove:

Namespaces (dev, argocd, monitoring)

Helm releases (ALB Controller, EFS CSI Driver, ArgoCD, Prometheus)

Orphaned AWS resources (ALBs, target groups, ENIs)

Run:

bash cleanup.sh

After cleanup, destroy Terraform-managed infrastructure:

terraform destroy --auto-approve

If subnets or resources fail to delete, run:

terraform destroy --auto-approve -target=module.eks
terraform destroy --auto-approve
Notes

ALB Ingress: Provides host-based routing for frontend.hex.com and backend.hex.com. Ensure DNS points to the ALB.

RBAC: All pods in dev namespace use dev-sa service account with limited permissions.

EFS: Configured using EFS CSI Driver for persistent storage (if used in workloads).

Monitoring & GitOps: Prometheus monitors cluster metrics; ArgoCD manages GitOps workflows.


References

Terraform AWS EKS Module

AWS EFS CSI Driver

AWS Load Balancer Controller

ArgoCD Helm Chart

Prometheus Helm Chart
