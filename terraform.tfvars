# ACHTUNG Kosten: c6i.metal kostet ca. $5,44/h pro Node (us-east-1, Stand 2026).
# Bei control_plane_count = 3 sind das ca. $16,32/h bzw. ~$11.760/Monat, solange der Cluster laeuft.
# Fuer reine Lern-/Testzwecke control_plane_count auf 1 reduzieren und den Cluster nach der
# Session mit "terraform destroy" wieder abbauen.
aws_region                  = "us-east-1"
cluster_name                = "talos-kvm-cluster"
talos_version               = "v1.12.9"
kubernetes_version          = "1.33.1"
control_plane_instance_type = "c6i.metal"
control_plane_count         = 3

vpc_cidr               = "10.0.0.0/16"
vpc_availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
vpc_public_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
vpc_private_subnets    = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]

# PFLICHT vor dem ersten "terraform apply": Kubernetes-API (6443) und Talos-API (50000) liegen
# auf einer oeffentlichen NLB mit echten Public IPs auf den Nodes (siehe README, Befund 4/6).
# "0.0.0.0/0" bedeutet: beide APIs sind fuer das gesamte Internet erreichbar, nur durch
# Kubernetes-/Talos-Auth geschuetzt. Eigene IP ermitteln z.B. mit: curl -4 ifconfig.me
# und danach ersetzen durch z.B. ["203.0.113.7/32"].
external_source_cidrs = ["0.0.0.0/0"]