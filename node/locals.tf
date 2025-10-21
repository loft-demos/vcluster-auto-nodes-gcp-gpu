locals {
  project = module.validation.project
  region  = module.validation.region
  zone    = module.validation.zone

  vcluster_name      = var.vcluster.instance.metadata.name
  vcluster_namespace = var.vcluster.instance.metadata.namespace

  network_name          = var.vcluster.nodeEnvironment.outputs.infrastructure["network_name"]
  subnet_name           = var.vcluster.nodeEnvironment.outputs.infrastructure["subnet_name"]
  service_account_email = var.vcluster.nodeEnvironment.outputs.infrastructure["service_account_email"]

  instance_type = var.vcluster.nodeType.spec.properties["instance-type"]

  # --- GPU (present only for GPU NodeTypes) ---
  gpu_type   = try(var.vcluster.nodeType.spec.properties["gcp.accelerator.type"], "")
  gpu_count  = tonumber(try(var.vcluster.nodeType.spec.properties["gcp.accelerator.count"], 0))
  enable_gpu = length(trimspace(local.gpu_type)) > 0 && local.gpu_count > 0
}
