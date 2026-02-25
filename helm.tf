resource "null_resource" "helm_repo_setup" {
  depends_on = [null_resource.wait_for_cluster]

  provisioner "local-exec" {
    command = <<EOT
      echo Setting up Helm repositories...
      echo Adding Helm repositories...
      helm repo add eks https://aws.github.io/eks-charts/
      echo Updating Helm repositories...
      helm repo update
      echo Helm repo setup complete!
    EOT
    interpreter = ["cmd", "/c"]
  }
}

# Ensure Helm repos are ready
resource "time_sleep" "wait_for_helm" {
  depends_on = [null_resource.helm_repo_setup]
  create_duration = "10s"
}

##############################################
# Helm Releases for EFS CSI Driver, ALB Controller, ArgoCD, Prometheus
##############################################

# First: EFS CSI Driver
resource "helm_release" "efs_csi_driver" {
  name       = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  namespace  = "kube-system"
  
  depends_on = [
    module.eks,
    module.efs_csi_irsa,
    time_sleep.wait_for_helm
  ]

  set {
    name  = "controller.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "efs-csi-controller-sa"
  }

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.efs_csi_irsa.iam_role_arn
  }
}

# Second: ALB Controller
resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  
  depends_on = [
    module.eks,
    module.alb_controller_irsa,
    time_sleep.wait_for_helm
  ]

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.alb_controller_irsa.iam_role_arn
  }

  set {
    name  = "region"
    value = var.region_name
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }
}

# Third: Wait for ALB controller to be ready
resource "time_sleep" "wait_for_alb_controller" {
  depends_on = [helm_release.alb_controller]
  create_duration = "30s"
}

# Fourth: ArgoCD
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  timeout          = 300
  
  depends_on = [
    module.eks,
    time_sleep.wait_for_helm,
    helm_release.alb_controller
  ]

  set {
    name  = "configs.secret.argocdServerAdminPassword"
    value = "$2a$10$rVyBsFSVwWlUY4/Ub3k.feyzU3nLhxPPyKqd4N5Qq1qXkkV1yF1yO"
  }
}

# Fifth: Prometheus
resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 300
  
  depends_on = [
    module.eks,
    time_sleep.wait_for_helm,
    helm_release.alb_controller
  ]

  set {
    name  = "alertmanager.enabled"
    value = "false"
  }

  set {
    name  = "server.persistentVolume.enabled"
    value = "false"
  }

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }
}

# Sixth: Wait for everything to be ready
resource "time_sleep" "wait_for_helm_apps" {
  depends_on = [
    helm_release.efs_csi_driver,
    helm_release.alb_controller,
    helm_release.argocd,
    helm_release.prometheus
  ]
  create_duration = "20s"
}



/* CODE1
##############################################
# EFS CSI Driver
##############################################

resource "helm_release" "efs_csi_driver" {
  name       = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  #version    = "2.6.0"
  namespace  = "kube-system"

  dependency_update = true
  force_update      = true
  timeout           = 600

  depends_on = [
    module.eks,
    module.efs_csi_irsa
  ]

  set {
    name  = "controller.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.efs_csi_irsa.iam_role_arn
  }
}

##############################################
# AWS Load Balancer Controller
##############################################

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  #version    = "1.7.2"
  namespace  = "kube-system"

  dependency_update = true
  force_update      = true
  timeout           = 600

  depends_on = [
    module.eks,
    module.alb_controller_irsa
  ]

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "region"
    value = var.region_name
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.alb_controller_irsa.iam_role_arn
  }
}

##############################################
# ArgoCD
##############################################

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
 #version          = "5.51.6"
  namespace        = "argocd"
  create_namespace = true

  dependency_update = true
  force_update      = true
  timeout           = 600

  depends_on = [
    module.eks,
    helm_release.alb_controller
  ]
}

##############################################
# Prometheus
##############################################

resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
 #version          = "25.8.0"
  namespace        = "monitoring"
  create_namespace = true

  dependency_update = true
  force_update      = true
  timeout           = 600

  depends_on = [
    module.eks,
    helm_release.alb_controller
  ]

  set {
    name  = "alertmanager.enabled"
    value = "false"
  }

  set {
    name  = "server.persistentVolume.enabled"
    value = "false"
  }

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }
}







#CODE2
### Helm Repository Setup - Windows Compatible ####


/*resource "null_resource" "helm_repo_setup" {
  depends_on = [null_resource.wait_for_cluster]

  provisioner "local-exec" {
    command = <<EOT
      echo Setting up Helm repositories...
      helm repo list >nul 2>&1 || echo No repos configured
      helm repo remove aws-efs-csi-driver 2>nul || echo Repo not found, continuing...
      helm repo remove eks 2>nul || echo Repo not found, continuing...
      helm repo remove argo 2>nul || echo Repo not found, continuing...
      helm repo remove prometheus-community 2>nul || echo Repo not found, continuing...
      echo Adding Helm repositories...
      helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver/
      helm repo add eks https://aws.github.io/eks-charts/
      helm repo add argo https://argoproj.github.io/argo-helm/
      helm repo add prometheus-community https://prometheus-community.github.io/helm-charts/
      helm repo add eks https://aws.github.io/eks-charts
      helm repo update
      echo Updating Helm repositories...
      helm repo update
      echo Helm repo setup complete!
    EOT
    interpreter = ["cmd", "/c"]
  }
}

*/

