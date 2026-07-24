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
  description = "Which Google Compute Project should your workspace live in?"
  type        = string
  default     = "exalted-splicer-470804-k7"
}

# See https://registry.coder.com/modules/coder/gcp-region
module "gcp_region" {
  source = "registry.coder.com/coder/gcp-region/coder"

  # This ensures that the latest non-breaking version of the module gets downloaded, you can also pin the module version to prevent breaking changes in production.
  version = "~> 1.0"

  regions = ["us", "europe"]
  default = "us-west2-a"
}
locals {
  instance_types = {
    "e2-small"       = "E2 Small (2 vCPU, 2 GB)"
    "e2-medium"      = "E2 Medium (2 vCPU, 4 GB)"
    "e2-standard-2"  = "E2 Standard 2 (2 vCPU, 8 GB)"
    "e2-standard-4"  = "E2 Standard 4 (4 vCPU, 16 GB)"
    "e2-standard-8"  = "E2 Standard 8 (8 vCPU, 32 GB)"
    "e2-standard-16" = "E2 Standard 16 (16 vCPU, 64 GB)"
  }
}

data "coder_parameter" "instance_type" {
  name         = "instance_type"
  display_name = "Instance Type"
  description  = "Google Compute Engine machine type for the workspace."
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

data "coder_parameter" "disk_image" {
  name         = "disk_image"
  display_name = "Disk Image"
  description  = "Google Compute Engine boot image used when the persistent workspace disk is first created."
  type         = "string"
  default      = "debian-cloud/debian-11"
  mutable      = false
  order        = 3
}

provider "google" {
  zone    = module.gcp_region.value
  project = var.project_id
}

data "google_compute_default_service_account" "default" {}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

resource "google_compute_disk" "root" {
  name  = "coder-${data.coder_workspace.me.id}-root"
  type  = "pd-ssd"
  zone  = module.gcp_region.value
  image = data.coder_parameter.disk_image.value
  lifecycle {
    ignore_changes = [name, image]
  }
}

resource "coder_agent" "main" {
  auth = "google-instance-identity"
  arch = "amd64"
  os   = "linux"
  startup_script = templatefile("${path.module}/scripts/install-optional-tools.sh.tftpl", {
    ARG_INSTALL_GEMINI_CLI            = tostring(data.coder_parameter.install_gemini_cli.value)
    ARG_INSTALL_OH_MY_CLAUDE_SISYPHUS = tostring(data.coder_parameter.install_oh_my_claude_sisyphus.value)
    ARG_INSTALL_OH_MY_CODEX           = tostring(data.coder_parameter.install_oh_my_codex.value)
    ARG_INSTALL_OH_MY_OPENAGENT       = tostring(data.coder_parameter.install_oh_my_openagent.value)
    ARG_INSTALL_OPENCODE_CLI          = tostring(data.coder_parameter.install_opencode_cli.value)
  })

  metadata {
    key          = "cpu"
    display_name = "CPU Usage"
    interval     = 5
    timeout      = 5
    script       = <<-EOT
      #!/bin/bash
      set -e
      top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4 "%"}'
    EOT
  }
  metadata {
    key          = "memory"
    display_name = "Memory Usage"
    interval     = 5
    timeout      = 5
    script       = <<-EOT
      #!/bin/bash
      set -e
      free -m | awk 'NR==2{printf "%.2f%%\t", $3*100/$2 }'
    EOT
  }
  metadata {
    key          = "disk"
    display_name = "Disk Usage"
    interval     = 600 # every 10 minutes
    timeout      = 30  # df can take a while on large filesystems
    script       = <<-EOT
      #!/bin/bash
      set -e
      df /home/coder | awk '$NF=="/"{printf "%s", $5}'
    EOT
  }
}

resource "google_compute_instance" "dev" {
  zone         = module.gcp_region.value
  count        = data.coder_workspace.me.start_count
  name         = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}-root"
  machine_type = data.coder_parameter.instance_type.value
  network_interface {
    network = "default"
    access_config {
      // Ephemeral public IP
    }
  }
  boot_disk {
    auto_delete = false
    source      = google_compute_disk.root.name
  }
  service_account {
    email  = data.google_compute_default_service_account.default.email
    scopes = ["cloud-platform"]
  }
  # The startup script runs as root with no $HOME environment set up, so instead of directly
  # running the agent init script, create a user (with a homedir, default shell and sudo
  # permissions) and execute the init script as that user.
  metadata_startup_script = <<EOMETA
#!/usr/bin/env sh
set -eux

# If user does not exist, create it and set up passwordless sudo
if ! id -u "${local.linux_user}" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "${local.linux_user}"
  echo "${local.linux_user} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/coder-user
fi

exec sudo -u "${local.linux_user}" sh -c '${coder_agent.main.init_script}'
EOMETA
}

locals {
  # Ensure Coder username is a valid Linux username
  linux_user = lower(substr(data.coder_workspace_owner.me.name, 0, 32))
  kasmvnc_supported = !strcontains(lower(data.coder_parameter.disk_image.value), "ubuntu-2604") && !strcontains(lower(data.coder_parameter.disk_image.value), "resolute")
}

resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = google_compute_instance.dev[0].id

  item {
    key   = "type"
    value = google_compute_instance.dev[0].machine_type
  }
}

resource "coder_metadata" "home_info" {
  resource_id = google_compute_disk.root.id

  item {
    key   = "size"
    value = "${google_compute_disk.root.size} GiB"
  }
}
