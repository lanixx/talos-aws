module "talos" {
  source = "git::https://github.com/isovalent/terraform-aws-talos?ref=main"

  cluster_name          = var.cluster_name
  region                = var.aws_region
  vpc_id                = module.vpc.vpc_id
  external_source_cidrs = var.external_source_cidrs

  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  controlplane_count         = var.control_plane_count
  allow_workload_on_cp_nodes = true

  #deploy_external_cloud_provider_iam_policies = true

  control_plane = {
    instance_type = var.control_plane_instance_type
    root_block_device = [
      {
        volume_size = 100
        volume_type = "gp3"
      }
    ]
    config_patch_files = [
      "${path.module}/kvm-patch.yaml"
    ]    
    tags = {
      Role = "control-plane"
    }
  }

  worker_groups = []

#   worker_groups = {
#     wg1 = {
#       instance_type = var.control_plane_instance_type
#       desired_size  = 0
#       min_size      = 0
#       max_size      = 0
#     }
#   }

  # worker_config_patches = [
  #   yamlencode({
  #     machine = {
  #       kernel = {
  #         modules = [
  #           { name = "kvm" },
  #           { name = "kvm_intel" }
  #         ]
  #       }
  #     }
  #   })
  # ]

    tags = {
    Environment = "talos-nested-kvm"
  }
}