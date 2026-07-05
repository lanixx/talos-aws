module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name                 = "${var.cluster_name}-vpc"
  cidr                 = var.vpc_cidr
  azs                  = var.vpc_availability_zones
  public_subnets       = var.vpc_public_subnets
  private_subnets      = var.vpc_private_subnets
  # Alle Talos-Knoten laufen in den oeffentlichen Subnetzen (Modul-Vorgabe, siehe README).
  # Die privaten Subnetze werden aktuell von keiner Ressource genutzt, daher kein NAT-Gateway.
  # Sobald z.B. interne ELBs (kubernetes.io/role/internal-elb) benoetigt werden, hier wieder aktivieren.
  enable_nat_gateway   = false
  enable_dns_hostnames = true

  public_subnet_tags = {
    "type"                                      = "public"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "type"                                      = "private"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}