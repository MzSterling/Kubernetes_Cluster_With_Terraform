#!/bin/bash

# cleanup-eks.sh - Complete cleanup for YOUR code
echo "=== EKS Complete Cleanup Script ==="
echo "Started at: $(date)"

CLUSTER_NAME="my-eks-cluster"
REGION="us-west-2"

echo "1. Configuring kubectl for EKS cluster: $CLUSTER_NAME"
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME || true

echo "2. Testing connection..."
kubectl get nodes || true

echo "3. 📌 DELETING ALB INGRESS (releases AWS Load Balancer)..."
kubectl delete ingress -n dev app-ingress --wait=true --timeout=60s 2>/dev/null || true
echo "   ✓ Ingress deleted"

echo "4. 📌 DELETING ALL DEV NAMESPACE RESOURCES..."
kubectl delete all --all -n dev 2>/dev/null || true
kubectl delete pvc --all -n dev 2>/dev/null || true
kubectl delete pv --all -n dev 2>/dev/null || true
kubectl delete configmap --all -n dev 2>/dev/null || true
kubectl delete secret --all -n dev 2>/dev/null || true
kubectl delete serviceaccount --all -n dev 2>/dev/null || true
kubectl delete role --all -n dev 2>/dev/null || true
kubectl delete rolebinding --all -n dev 2>/dev/null || true
echo "   ✓ Dev resources deleted"

echo "5. 📌 DELETING DEV NAMESPACE..."
kubectl delete ns dev --wait=true --timeout=60s 2>/dev/null || true
kubectl delete ns dev --force --grace-period=0 2>/dev/null || true
echo "   ✓ Dev namespace deleted"

echo "6. 📌 DELETING ARGOCD NAMESPACE..."
kubectl delete ns argocd --wait=true --timeout=60s 2>/dev/null || true
kubectl delete ns argocd --force --grace-period=0 2>/dev/null || true
echo "   ✓ ArgoCD namespace deleted"

echo "7. 📌 DELETING MONITORING NAMESPACE..."
kubectl delete ns monitoring --wait=true --timeout=60s 2>/dev/null || true
kubectl delete ns monitoring --force --grace-period=0 2>/dev/null || true
echo "   ✓ Monitoring namespace deleted"

echo "8. 📌 UNINSTALLING ALB CONTROLLER HELM RELEASE..."
helm uninstall -n kube-system aws-load-balancer-controller 2>/dev/null || true
kubectl delete deployment -n kube-system aws-load-balancer-controller 2>/dev/null || true
kubectl delete serviceaccount -n kube-system aws-load-balancer-controller 2>/dev/null || true
kubectl delete clusterrolebinding aws-load-balancer-controller 2>/dev/null || true
kubectl delete clusterrole aws-load-balancer-controller 2>/dev/null || true
echo "   ✓ ALB Controller uninstalled"

echo "9. 📌 UNINSTALLING EFS CSI DRIVER HELM RELEASE..."
helm uninstall -n kube-system aws-efs-csi-driver 2>/dev/null || true
kubectl delete deployment -n kube-system efs-csi-controller 2>/dev/null || true
kubectl delete daemonset -n kube-system efs-csi-node 2>/dev/null || true
kubectl delete serviceaccount -n kube-system efs-csi-controller-sa 2>/dev/null || true
kubectl delete clusterrolebinding efs-csi 2>/dev/null || true
kubectl delete clusterrole efs-csi 2>/dev/null || true
kubectl delete csidriver efs.csi.aws.com 2>/dev/null || true
echo "   ✓ EFS CSI Driver uninstalled"

echo "10. 📌 DELETING ARGOCD CRDS..."
kubectl delete crd applications.argoproj.io --wait=false 2>/dev/null || true
kubectl delete crd applicationsets.argoproj.io --wait=false 2>/dev/null || true
kubectl delete crd appprojects.argoproj.io --wait=false 2>/dev/null || true

# Force remove finalizers from ArgoCD CRDs
for crd in applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io; do
    kubectl patch crd/$crd -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
    kubectl delete crd $crd --wait=false 2>/dev/null || true
done
echo "   ✓ ArgoCD CRDs deleted"

echo "11. 📌 CLEANING UP HELM REPOSITORIES..."
helm repo remove aws-efs-csi-driver 2>/dev/null || true
helm repo remove eks 2>/dev/null || true
helm repo remove argo 2>/dev/null || true
helm repo remove prometheus-community 2>/dev/null || true
helm repo update 2>/dev/null || true
echo "   ✓ Helm repos cleaned"

echo "12. ⏳ WAITING 60 SECONDS FOR AWS TO CLEAN UP RESOURCES..."
sleep 60

echo "13. 📌 CLEANING UP ORPHANED AWS RESOURCES..."
# Delete any remaining ALBs
aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[?contains(LoadBalancerName, 'my-eks-cluster')].[LoadBalancerArn]" --output text 2>/dev/null | while read alb; do
    echo "   Deleting ALB: $alb"
    aws elbv2 delete-load-balancer --load-balancer-arn $alb --region $REGION 2>/dev/null || true
done

# Delete target groups
aws elbv2 describe-target-groups --region $REGION --query "TargetGroups[?contains(TargetGroupName, 'my-eks-cluster')].[TargetGroupArn]" --output text 2>/dev/null | while read tg; do
    echo "   Deleting Target Group: $tg"
    aws elbv2 delete-target-group --target-group-arn $tg --region $REGION 2>/dev/null || true
done

# Delete orphaned ENIs
aws ec2 describe-network-interfaces --region $REGION --filters "Name=description,Values=*my-eks-cluster*" --query "NetworkInterfaces[?Status=='available'].[NetworkInterfaceId]" --output text 2>/dev/null | while read eni; do
    echo "   Deleting orphaned ENI: $eni"
    aws ec2 delete-network-interface --network-interface-id $eni --region $REGION 2>/dev/null || true
done

echo "14. ✅ FINAL CHECK - Verifying no stuck namespaces..."
for ns in dev argocd monitoring; do
    if kubectl get ns $ns &>/dev/null; then
        echo "   Force deleting namespace $ns..."
        kubectl get namespace $ns -o json | jq 'del(.spec.finalizers[]? | select(. == "kubernetes"))' 2>/dev/null | kubectl replace --raw /api/v1/namespaces/$ns/finalize -f - 2>/dev/null || true
    fi
done

echo ""
echo "=================================================="
echo "✅✅✅ CLEANUP COMPLETE! ✅✅✅"
echo "=================================================="
echo "Next step: Run terraform destroy --auto-approve"
echo ""
echo "If destroy fails on subnets, wait 2 minutes and run:"
echo "terraform destroy --auto-approve -target=module.eks && terraform destroy --auto-approve"
echo "=================================================="
echo "Finished at: $(date)"

# Ater clean up, initiate a terraform destroy, to destroy your infrastructure set up