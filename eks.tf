module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "eks-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true # Required for nodes to talk to ECR
  single_nat_gateway = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = true
  
  cluster_name    = "my-microservice-cluster"
  cluster_version = "1.30" #standard for 2026

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.public_subnets

  # EKS Managed Node Group (The EC2s that run your code)
  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t3.medium"] # t3.medium is more stable for EKS than t3.micro
      capacity_type  = "ON_DEMAND"
      ami_type = "AL2023_x86_64_STANDARD" #force amazon linux 2023
    }
  }
  tags = {
      Environment = "dev"
      Project     = "MicroserviceCluster"
  }
  enable_cluster_creator_admin_permissions = true
}