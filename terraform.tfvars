aws_region                  = "us-east-1"
cluster_name                = "talos-kvm-cluster"
talos_version               = "v1.12.9"
kubernetes_version          = "1.33.1"
control_plane_instance_type = "m8i.large"
control_plane_count         = 3
# worker_instance_type        = "m8i.2xlarge"
# worker_count                = 2

vpc_cidr               = "10.0.0.0/16"
vpc_availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
vpc_public_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
vpc_private_subnets    = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]

# Ersetzen Sie dies durch Ihre öffentliche IP-Adresse (z.B. "85.214.0.1/32") oder "0.0.0.0/0" zum Testen
external_source_cidrs  = ["0.0.0.0/0"]