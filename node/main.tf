provider "google" {
  project = local.project
  region  = local.region
}

module "validation" {
  source = "./validation"

  project = nonsensitive(var.vcluster.properties["project"])
  region  = nonsensitive(var.vcluster.properties["region"])
  zone    = try(nonsensitive(var.vcluster.properties["zone"]), "")
}

resource "random_id" "vm_suffix" {
  byte_length = 4
}

module "private_instance" {
  source  = "terraform-google-modules/vm/google//modules/compute_instance"
  version = "~> 13.0"

  region            = local.region
  zone              = local.zone == "" ? null : local.zone
  subnetwork        = local.subnet_name
  num_instances     = 1
  hostname          = "${var.vcluster.name}-${random_id.vm_suffix.hex}"
  instance_template = module.instance_template.self_link

  # Will use NAT
  access_config = []

  labels = {
    vcluster  = local.vcluster_name
    namespace = local.vcluster_namespace

    # the same as the value set in CCM’s --cluster-name flag
    cluster-name = local.vcluster_name
  }

  # ←← Attach GPUs ONLY when enable_gpu=true
  dynamic "guest_accelerator" {
    for_each = local.enable_gpu ? [1] : []
    content {
      type  = local.gpu_type          # e.g. "nvidia-tesla-t4" or "nvidia-l4"
      count = local.gpu_count         # e.g. 1
    }
  }

  # ←← Required for GPU VMs (no live migration). This overrides the template.
  dynamic "scheduling" {
    for_each = local.enable_gpu ? [1] : []
    content {
      on_host_maintenance = "TERMINATE"
      automatic_restart   = true
      preemptible         = false     # set true if you want Spot
    }
  }
}

data "google_project" "project" {
  project_id = local.project
}

data "google_compute_image" "img" {
  family  = "ubuntu-2404-lts-amd64"
  project = "ubuntu-os-cloud"
}

module "instance_template" {
  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "~> 13.0"

  region             = local.region
  project_id         = local.project
  network            = local.network_name
  subnetwork         = local.subnet_name
  subnetwork_project = local.project
  tags               = ["allow-iap-ssh", local.vcluster_name] # for IAP SSH access

  machine_type = local.instance_type

  source_image         = data.google_compute_image.img.self_link
  source_image_family  = data.google_compute_image.img.family
  source_image_project = data.google_compute_image.img.project

  disk_size_gb = 100
  disk_type    = "pd-standard"

  service_account = {
    email  = local.service_account_email
    scopes = ["cloud-platform"]
  }

  metadata = {
    user-data = var.vcluster.userData
  }

  startup_script = "#!/bin/bash\n# Ensure cloud-init runs\ncloud-init status --wait || true"
}
