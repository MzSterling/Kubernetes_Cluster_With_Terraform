
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
  cluster_name                    = "my-eks-cluster"
  cluster_version                 = "1.29"
  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets
  enable_irsa                     = true
  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true
  eks_managed_node_groups = {
    initial = {
      min_size        = 2
      max_size        = 4
      desired_size    = 2
      instance_types = ["t3.medium"]
      
    }
  }
  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

#Wait for the cluster to be fully ready ready 

resource "null_resource" "wait_for_cluster" {
  depends_on = [module.eks]
  provisioner "local-exec" {
    command = <<EOT
      aws eks wait cluster-active --region ${var.region_name} --name my-eks-cluster
      aws eks update-kubeconfig --region ${var.region_name} --name my-eks-cluster
      echo "Waiting for cluster to be ready..."
      sleep 30
    EOT
    interpreter= ["cmd", "/c"]
  }
}
