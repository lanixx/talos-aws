variable "aws_region" {
  type        = string
  description = "Die AWS-Region, in der das Cluster bereitgestellt wird."
}

variable "cluster_name" {
  type        = string
  description = "Der Name des Talos Kubernetes-Clusters."
}

variable "talos_version" {
  type        = string
  description = "Die Version von Talos Linux."
}

variable "kubernetes_version" {
  type        = string
  description = "Die Version von Kubernetes."
}

variable "control_plane_instance_type" {
  type        = string
  description = "Der EC2-Instanztyp für die Control Plane Nodes."
}

variable "control_plane_count" {
  type        = number
  description = "Anzahl der Control Plane Nodes."
}

# variable "worker_instance_type" {
#   type        = string
#   description = "Der EC2-Instanztyp für die Worker Nodes."
# }

# variable "worker_count" {
#   type        = number
#   description = "Anzahl der Worker Nodes."
# }

variable "vpc_cidr" {
  type        = string
  description = "Der CIDR-Block für das VPC."
}

variable "vpc_availability_zones" {
  type        = list(string)
  description = "Die Verfügbarkeitszonen für die Subnetze im VPC."
}

variable "vpc_public_subnets" {
  type        = list(string)
  description = "Die CIDR-Blöcke für die öffentlichen Subnetze."
}

variable "vpc_private_subnets" {
  type        = list(string)
  description = "Die CIDR-Blöcke für die privaten Subnetze."
}

variable "external_source_cidrs" {
  type        = list(string)
  description = "Erlaubte externe IP-Adressen (z.B. Ihre eigene IP '/32') für administrative Zugriffe."
}