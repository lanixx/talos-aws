
# Talos Linux on AWS with Nested Virtualization

**Repository:** [lanixx/talos-aws](https://github.com/lanixx/talos-aws)

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Known Limitations](#3-known-limitations)
4. [Prerequisites](#4-prerequisites)
5. [Deployment – Step by Step](#5-deployment--step-by-step)
6. [Configuration Reference](#6-configuration-reference)
7. [FAQ](#7-faq)
8. [Troubleshooting](#8-troubleshooting)
9. [Cluster Teardown](#9-cluster-teardown)
10. [Further Links](#10-further-links)


## 1. Overview

This repository provisions a Talos Linux Kubernetes cluster on AWS EC2 using Terraform. The core goal is a cluster with hardware-near nested virtualization as a foundation for future VM workloads – via KubeVirt or as a base for OpenStack via Yaook. The orchestration utilizes the community module [isovalent/terraform-aws-talos](https://github.com/isovalent/terraform-aws-talos), which largely automates the Talos bootstrapping process.

The setup is a learning/experimental project, not a production-ready reference design. It consists of a pure control-plane cluster (no separate workers), which is defined via a handful of Terraform files and an installation script for Cilium.

| File | Purpose |
|---|---|
| `README.md` | This documentation |
| `main.tf` | Terraform/provider versions |
| `vpc.tf` | VPC with public and private subnets across 3 Availability Zones |
| `talos.tf` | Integration of the Isovalent module, control-plane definition |
| `kvm-patch.yaml` | Talos machine config patch: KVM kernel modules, worker label |
| `variables.tf` | Variable declarations |
| `terraform.tfvars` | Concrete values (region, instance type, CIDRs, …) |
| `outputs.tf` | Outputs for `kubeconfig` and `talosconfig` |
| `scripts/install-cilium.sh` | Installs Cilium as CNI after the bootstrap |


## 2. Architecture

Terraform initially provisions a VPC with three public and three private subnets (one per Availability Zone). The public subnets are tagged with `type=public`, the private ones with `type=private` – this tagging is actively evaluated by the Isovalent module to place its resources.

**All cluster nodes run in the public subnets with a public IP address.** This is a requirement of the underlying Terraform module: the Talos provider communicates directly with the Talos API (port 50000) of each node via the public IP during bootstrap and configuration. The private subnets have the necessary tags but are currently not used by any resource – they serve as a foundation for future internal load balancers, should Kubernetes services require them. A NAT gateway is therefore intentionally not activated.

The control-plane nodes run on virtualized Nitro instances of the `m7i.xlarge` class – intentionally not a bare-metal instance. Bare-metal instances on AWS do not support UEFI boot (only legacy BIOS), but the official Talos AMI is UEFI-based; a `.metal` type would fail during instance startup with a boot mode error before nested virtualization is even considered. `m7i` was additionally chosen specifically because the family belongs to the AWS instance types that are fundamentally intended for the CPU option `cpu_options.nested_virtualization` (details on this in Section 3).

A Network Load Balancer (created by the Isovalent module) serves as a stable endpoint for the Kubernetes API (6443) and Talos API (50000) across all three control-plane nodes. The cluster dispenses with dedicated worker nodes (`worker_groups = []`); by removing the standard taints (`allow_workload_on_cp_nodes = true`), the three control-plane nodes simultaneously assume the worker role. The AWS Cloud Controller Manager is activated (`enable_external_cloud_provider = true`, `deploy_external_cloud_provider_iam_policies = true`), allowing Kubernetes to use the AWS API for node metadata and future load balancer provisioning.

| Component | Origin | Role |
|---|---|---|
| VPC + Subnets | `vpc.tf` | Network basis; private subnets currently unused |
| Network Load Balancer | Isovalent module | Endpoint for Kubernetes and Talos API |
| 3× EC2 Instance `m7i.xlarge` | Isovalent module | Etcd, API Server, Kubelet, KVM Host |
| `kvm-patch.yaml` | this repository | Kernel modules `kvm`/`kvm_intel`, worker label |
| AWS Cloud Controller Manager | Isovalent module, enabled | Node metadata, basis for dynamic ELBs |
| `scripts/install-cilium.sh` | this repository | CNI installation after bootstrap |
| `talosconfig` / `kubeconfig` | Terraform outputs | Administrative access |


## 3. Known Limitations

**No hardware-accelerated nested virtualization (currently).** `kvm-patch.yaml` loads the kernel modules `kvm`/`kvm_intel` with the parameters `nested=1` and `ept=1`. AWS now supports true hardware nested virtualization even on virtualized (non-metal) instances of the `c7i`/`m7i`/`r7i`/`c8i`/`m8i`/`r8i` families – provided the CPU option `cpu_options.nested_virtualization = enabled` is set during instance startup. The Terraform module used here does not currently pass this option through for its control-plane instances (the interface only knows `instance_type`, `config_patch_files`, and `tags`). Without this CPU option, KVM remains restricted to software emulation (TCG) – functional for initial tests, but noticeably slower than true hardware virtualization. To close this gap, the module would need to be extended with a `cpu_options` block (fork or upstream contribution).

**Root volume fixed at 50 GB (gp3).** The `control_plane` block of the module used does not support a `root_block_device` attribute. An attempt to set the root volume size through it is rejected by Terraform's type system as an undeclared attribute (validation error during `terraform plan`, not silently ignored). For larger storage requirements – such as image storage for OpenStack/Yaook – an additional, separate EBS volume is currently recommended instead of an enlarged root volume.

**No CNI pre-installed.** The Kubernetes network configuration is intentionally set to `cni: none` and kube-proxy is disabled so that the choice of CNI remains open. Without the manual installation step described in Section 5, all nodes remain permanently `NotReady`.

**Kubernetes and Talos API are globally accessible by default.** The default value for `external_source_cidrs` is `0.0.0.0/0`. In combination with the public IP addresses of the nodes, this means: both APIs are accessible from the entire internet from the first `terraform apply` until this variable is restricted (see Section 5.3).

## 4. Prerequisites

**Local tools:**

| Tool | Purpose |
|---|---|
| Terraform ≥ 1.5.0 | Infrastructure provisioning |
| `git` | Required by `terraform init`, as the Talos module is referenced via Git URL |
| AWS CLI v2 | Authentication |
| `talosctl` | Cluster administration ([Sidero Labs Releases](https://github.com/siderolabs/talos/releases)) |
| `kubectl` | Kubernetes administration |
| `helm` | Required by `scripts/install-cilium.sh` |

**AWS-side:**

- Account with permissions for EC2, VPC, ELB/NLB, and IAM policy creation (for the Cloud Controller Manager).
- Knowledge of your own public IP address for `external_source_cidrs`.
- For `m7i.xlarge`, the standard service quotas are usually sufficient.

## 5. Deployment – Step by Step

### 5.1 Set up AWS access

```bash
aws sso login --profile <your-sso-profile>
export AWS_PROFILE=<your-sso-profile>
```

### 5.2 Clone repository

```bash
git clone https://github.com/lanixx/talos-aws.git
cd talos-aws
```

### 5.3 Check `terraform.tfvars`

Before the first `apply`, determine your own IP and restrict `external_source_cidrs` accordingly:

```bash
curl -4 ifconfig.me
```

Enter the return value as `"<your-IP>/32"`. **Without this step, the Kubernetes and Talos API will remain globally accessible** (see Section 3). For quick tests, `control_plane_count` can be reduced to `1` to save costs.

### 5.4 Initialize and execute Terraform

```bash
terraform init
terraform plan
terraform apply
```

Experience shows the deployment takes several minutes: VPC and load balancer creation, waiting for tagged subnets, AMI boot, and Talos bootstrap (etcd initialization) run sequentially.

### 5.5 Extract credentials

```bash
terraform output -raw kubeconfig  > kubeconfig
terraform output -raw talosconfig > talosconfig

export KUBECONFIG="$(pwd)/kubeconfig"
export TALOSCONFIG="$(pwd)/talosconfig"
```

### 5.6 Check basic status

```bash
talosctl version
kubectl get nodes -o wide
```

A `NotReady` status of all nodes is normal and expected at this point (see Section 3) – not yet an error.

### 5.7 Install CNI

```bash
./scripts/install-cilium.sh
```

The script retrieves the credentials itself via `terraform output`, installs Cilium via Helm with the appropriate values for Talos (including `kubeProxyReplacement=true`, KubePrism to `localhost:7445`), and then waits up to 5 minutes for ready nodes.

### 5.8 Check result

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

All three nodes should now be `Ready`. For the actual VM workload use case, an additional operator is necessary – KubeVirt (`kubectl apply -f https://github.com/kubevirt/kubevirt/releases/…/kubevirt-operator.yaml`) or Yaook for OpenStack; neither is part of this repository.

## 6. Configuration Reference

| Variable | Value | Note |
|---|---|---|
| `aws_region` | `us-east-1` | |
| `cluster_name` | `talos-kvm-cluster` | |
| `talos_version` | `v1.12.9` | |
| `kubernetes_version` | `1.33.1` | |
| `control_plane_instance_type` | `m7i.xlarge` | See Section 2/3 regarding instance type choice |
| `control_plane_count` | `3` | Can be reduced to `1` for quick tests |
| `vpc_cidr` | `10.0.0.0/16` | |
| `vpc_availability_zones` | `us-east-1a`, `us-east-1b`, `us-east-1c` | |
| `vpc_public_subnets` | `10.0.1.0/24`–`10.0.3.0/24` | All nodes run here |
| `vpc_private_subnets` | `10.0.11.0/24`–`10.0.13.0/24` | No NAT gateway, currently unused |
| `external_source_cidrs` | `["0.0.0.0/0"]` | **Restrict before use (Section 5.3)** |
| `enable_external_cloud_provider` | `true` | Activates the AWS Cloud Controller Manager |
| `deploy_external_cloud_provider_iam_policies` | `true` | Necessary IAM policies for it |
| Root Volume | 50 GB, gp3 (Module default) | Not configurable, see Section 3 |

**Cost estimate** (On-Demand, us-east-1, without guarantee – check current prices at [aws.amazon.com/ec2/pricing](https://aws.amazon.com/ec2/pricing/on-demand/)): `m7i.xlarge` is approx. **$0.09/hr** per node, so with three continuously running nodes approx. **$195/month**. Do not forget: `terraform destroy` after each test (Section 9).

## 7. FAQ

**Why no bare-metal instance if the goal is nested virtualization?**
Bare-metal instances on AWS do not support UEFI boot, but the official Talos AMI requires UEFI – the instance startup would fail with a boot mode error before nested virtualization even becomes relevant. `m7i.xlarge` supports UEFI and additionally belongs to the instance families that AWS fundamentally intends for the CPU option `cpu_options.nested_virtualization` – even if this option is currently not passed through (Section 3).

**Why is `worker_groups` an empty array?**
So that the cluster consists exclusively of the three control-plane nodes. `allow_workload_on_cp_nodes = true` removes the standard taints, meaning these nodes simultaneously function as workers; separate, additional instances are thereby omitted.

**What is the function of the Load Balancer?**
It is a Network Load Balancer responsible for the Kubernetes API (6443) and Talos API (50000) – a stable, shared endpoint across all control-plane nodes, not a security gateway. The nodes have their own public IP addresses anyway; the actual access restriction takes place via `external_source_cidrs`.

**Is the AWS Cloud Controller Manager active?**
Yes, `enable_external_cloud_provider` and `deploy_external_cloud_provider_iam_policies` are both set.

**Do I have to install a CNI manually?**
Yes, via `./scripts/install-cilium.sh` after the first successful `terraform apply` (Section 5.7).

**What does a test deployment roughly cost?**
Around $195/month for continuous operation of all three nodes (Section 6) – significantly dependent on how long the cluster actually runs.

**Is there a license for this repository?**
The repository does not contain a `LICENSE` file.

## 8. Troubleshooting

**`terraform apply` fails with a boot mode/UEFI error**
Occurs if `control_plane_instance_type` is changed to a `.metal` type. Bare-metal instances do not support UEFI, but the Talos AMI does (see Section 2/3). Stick with a virtualized type like `m7i.xlarge`.

**`terraform apply` hangs while waiting for subnets**
The underlying module waits for three subnets with the tag `type=public` in the VPC. The cause is practically always a tagging problem in `vpc.tf`. Check with:

```bash
aws ec2 describe-subnets --filters Name=vpc-id,Values=<vpc-id> Name=tag:type,Values=public
```

**Nodes remain permanently `NotReady` after startup**
In most cases, the CNI installation step is missing – execute `./scripts/install-cilium.sh` (Section 5.7). `kubectl describe node <node>` typically shows a condition like `NetworkPluginNotReady` in this case.

**`install-cilium.sh` aborts with "helm is not installed"**
Install `helm` locally: [helm.sh/docs/intro/install](https://helm.sh/docs/intro/install/).

**`terraform output -raw kubeconfig_pfad` or `talosconfig_pfad` returns an error**
These outputs do not exist. To access the credentials, use `terraform output -raw kubeconfig` or `terraform output -raw talosconfig` (returns the raw content, not a file path) and redirect it to a file as described in Section 5.5.

**Terraform validation errors regarding `config_patches`**
The module manages cluster roles autonomously. Referenced patch files must therefore not contain scheduling parameters at the cluster level, but must be limited to the `machine` block – as already implemented in `kvm-patch.yaml` (kernel modules, `nested=1`/`ept=1`, worker label).

**Terraform validation error when setting `root_block_device`**
The `control_plane` block of this module does not know this attribute (only `instance_type`, `config_patch_files`, `tags`). There is currently no direct path provided via this module for a larger root disk (see Section 3).

**`terraform destroy` hangs or the VPC cannot be deleted**
If Kubernetes services of type `LoadBalancer` were created, the Cloud Controller Manager generates ELBs for them outside of the Terraform state. Before `terraform destroy`, delete all such services and wait briefly until AWS has removed the associated load balancers:

```bash
kubectl get svc -A | grep LoadBalancer
kubectl delete svc <name> -n <namespace>
```

## 9. Cluster Teardown

```bash
# Beforehand: delete all Kubernetes services of type LoadBalancer
kubectl get svc -A | grep LoadBalancer
kubectl delete svc <name> -n <namespace>

terraform destroy
```

Afterwards, check via the AWS Console (EC2 instances, NLB, EIPs) whether all chargeable resources have actually been removed.

## 10. Further Links

- Repository: [github.com/lanixx/talos-aws](https://github.com/lanixx/talos-aws)
- Underlying Terraform module: [github.com/isovalent/terraform-aws-talos](https://github.com/isovalent/terraform-aws-talos)
- AWS – Boot modes of instance types: [docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-type-boot-mode.html](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-type-boot-mode.html)
- AWS – Nested virtualization on virtualized instances: [docs.aws.amazon.com/AWSEC2/latest/UserGuide/amazon-ec2-nested-virtualization.html](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/amazon-ec2-nested-virtualization.html)
- Talos + Cilium: [docs.siderolabs.com/kubernetes-guides/cni/deploying-cilium](https://docs.siderolabs.com/kubernetes-guides/cni/deploying-cilium)
- KubeVirt: [kubevirt.io](https://kubevirt.io/)
- AWS EC2 On-Demand pricing: [aws.amazon.com/ec2/pricing/on-demand](https://aws.amazon.com/ec2/pricing/on-demand/)
