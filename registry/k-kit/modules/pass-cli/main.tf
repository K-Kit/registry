terraform {
  required_version = ">= 1.0"

  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.13"
    }
  }
}

variable "agent_id" {
  description = "The ID of a Coder agent."
  type        = string
}

variable "personal_access_token" {
  description = "Proton Pass personal access token used to authenticate the CLI non-interactively."
  type        = string
  default     = ""
  sensitive   = true
}

variable "install_channel" {
  description = "Proton Pass CLI release track installed by the official installer."
  type        = string
  default     = "stable"

  validation {
    condition     = contains(["stable", "beta"], var.install_channel)
    error_message = "install_channel must be either stable or beta."
  }
}

variable "install_dir" {
  description = "Directory where the Proton Pass CLI binary is installed."
  type        = string
  default     = "$HOME/.local/bin"

  validation {
    condition = (
      startswith(var.install_dir, "/") ||
      startswith(var.install_dir, "$HOME/") ||
      startswith(var.install_dir, "~/")
    )
    error_message = "install_dir must be an absolute path or start with $HOME/ or ~/."
  }
}

variable "icon" {
  description = "Icon shown for the Proton Pass CLI lifecycle scripts."
  type        = string
  default     = "/icon/proton-pass.svg"
}

variable "pre_install_script" {
  description = "Custom script to run before installing the Proton Pass CLI."
  type        = string
  default     = null
}

variable "post_install_script" {
  description = "Custom script to run after installing and configuring the Proton Pass CLI."
  type        = string
  default     = null
}

locals {
  module_directory = "$HOME/.coder-modules/k-kit/pass-cli"

  install_script = templatefile("${path.module}/scripts/install.sh.tftpl", {
    ARG_INSTALL_CHANNEL = var.install_channel
    ARG_INSTALL_DIR_B64 = base64encode(var.install_dir)
  })
}

resource "coder_env" "personal_access_token" {
  count    = var.personal_access_token != "" ? 1 : 0
  agent_id = var.agent_id
  name     = "PROTON_PASS_PERSONAL_ACCESS_TOKEN"
  value    = var.personal_access_token
}

module "coder_utils" {
  source  = "registry.coder.com/coder/coder-utils/coder"
  version = "0.0.1"

  agent_id            = var.agent_id
  module_directory    = local.module_directory
  display_name_prefix = "Proton Pass CLI"
  icon                = var.icon
  pre_install_script  = var.pre_install_script
  install_script      = local.install_script
  post_install_script = var.post_install_script
}

output "scripts" {
  description = "Ordered list of coder exp sync names produced by the Proton Pass CLI install pipeline."
  value       = module.coder_utils.scripts
}
