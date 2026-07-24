terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    google = {
      source = "hashicorp/google"
    }
  }
}

provider "coder" {}

variable "project_id" {
  description = "Google Cloud project in which workspace instances are created."
  type        = string
  default     = "exalted-splicer-470804-k7"
}

module "gcp_region" {
  source  = "registry.coder.com/coder/gcp-region/coder"
  version = "~> 1.0"
  regions = ["us", "europe"]
  default = "us-west2-a"
}

provider "google" {
  zone    = module.gcp_region.value
  project = var.project_id
}

data "google_compute_default_service_account" "default" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

locals {
  instance_types = {
    "e2-small"       = "E2 Small (2 vCPU, 2 GB)"
    "e2-medium"      = "E2 Medium (2 vCPU, 4 GB)"
    "e2-standard-2"  = "E2 Standard 2 (2 vCPU, 8 GB)"
    "e2-standard-4"  = "E2 Standard 4 (4 vCPU, 16 GB)"
    "e2-standard-8"  = "E2 Standard 8 (8 vCPU, 32 GB)"
    "e2-standard-16" = "E2 Standard 16 (16 vCPU, 64 GB)"
  }

  bootstrap_script = <<-EOT
    set -e
    export DEBIAN_FRONTEND=noninteractive

    echo 'DPkg::Lock::Timeout "300";' | sudo tee /etc/apt/apt.conf.d/99coder-lock-timeout >/dev/null
    echo 'APT::Update::Lock::Timeout "300";' | sudo tee -a /etc/apt/apt.conf.d/99coder-lock-timeout >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y build-essential ca-certificates curl python3 tar unzip zsh
    mkdir -p "$HOME/.coder-modules/coder/filebrowser"

    if ! command -v uv >/dev/null 2>&1; then
      curl -LsSf https://astral.sh/uv/install.sh | sh
      sudo ln -sf "$HOME/.local/bin/uv" /usr/local/bin/uv
    fi

    ${coder_agent.main.init_script}
  EOT
}

data "coder_parameter" "instance_type" {
  name         = "instance_type"
  display_name = "Instance Type"
  description  = "Google Compute Engine machine type for the container host."
  type         = "string"
  form_type    = "dropdown"
  default      = "e2-medium"
  mutable      = false
  order        = 2

  dynamic "option" {
    for_each = local.instance_types
    content {
      name  = option.value
      value = option.key
    }
  }
}

data "coder_parameter" "container_image" {
  name         = "container_image"
  display_name = "Container Image"
  description  = "OCI image used for the workspace container. It must be Debian or Ubuntu based and include sudo."
  type         = "string"
  default      = "codercom/enterprise-base:ubuntu"
  mutable      = true
  order        = 3
}

resource "coder_agent" "main" {
  auth = "google-instance-identity"
  arch = "amd64"
  os   = "linux"

  metadata {
    key          = "cpu"
    display_name = "CPU Usage"
    interval     = 5
    timeout      = 5
    script       = "coder stat cpu"
  }

  metadata {
    key          = "memory"
    display_name = "Memory Usage"
    interval     = 5
    timeout      = 5
    script       = "coder stat mem"
  }

  metadata {
    key          = "disk"
    display_name = "Disk Usage"
    interval     = 5
    timeout      = 5
    script       = "coder stat disk"
  }
}

module "gce_container" {
  source  = "terraform-google-modules/container-vm/google"
  version = "3.0.0"

  container = {
    image   = data.coder_parameter.container_image.value
    command = ["bash"]
    args    = ["-lc", local.bootstrap_script]
    securityContext = {
      privileged = true
    }
  }
}

resource "google_compute_instance" "workspace" {
  count        = data.coder_workspace.me.start_count
  name         = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
  machine_type = data.coder_parameter.instance_type.value
  zone         = module.gcp_region.value

  network_interface {
    network = "default"
    access_config {}
  }

  boot_disk {
    initialize_params {
      image = module.gce_container.source_image
      size  = 50
      type  = "pd-ssd"
    }
  }

  service_account {
    email  = data.google_compute_default_service_account.default.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    "gce-container-declaration" = module.gce_container.metadata_value
  }

  labels = {
    container-vm = module.gce_container.vm_container_label
  }
}

resource "coder_agent_instance" "workspace" {
  count       = data.coder_workspace.me.start_count
  agent_id    = coder_agent.main.id
  instance_id = google_compute_instance.workspace[0].instance_id
}

resource "coder_metadata" "workspace" {
  count       = data.coder_workspace.me.start_count
  resource_id = google_compute_instance.workspace[0].id

  item {
    key   = "instance_type"
    value = google_compute_instance.workspace[0].machine_type
  }

  item {
    key   = "image"
    value = module.gce_container.container.image
  }

  item {
    key   = "zone"
    value = module.gcp_region.value
  }
}
