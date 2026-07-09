# Bare-Metal-Instanzen (*.metal) unterstuetzen auf AWS kategorisch kein UEFI-Boot, die offizielle
# Talos-AMI ist aber strikt auf boot_mode=uefi registriert -> *.metal kann diese AMI nicht booten
# (siehe README, Befund 1). Daher virtualisierte Nitro-Instanz statt Bare-Metal.
# c7i ist bewusst gewaehlt, weil die Familie seit Feb. 2026 zu den AWS-Instanztypen gehoert, die
# spaeter per cpu_options.nested_virtualization=enabled echte Hardware-Nested-Virtualization
# unterstuetzen koennten (erfordert einen Fork von isovalent/terraform-aws-talos, siehe README).
# Bis dieser Fork existiert, laden die kvm/kvm_intel-Kernelmodule zwar, KVM faellt aber mangels
# VMX-Passthrough auf Software-Emulation (TCG) zurueck - funktional, aber langsam.
aws_region                  = "us-east-1"
cluster_name                = "talos-kvm-cluster"
talos_version               = "v1.12.9"
kubernetes_version          = "1.33.1"
control_plane_instance_type = "m7i.large"
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
