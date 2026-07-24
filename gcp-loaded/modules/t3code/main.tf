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

variable "port" {
  description = "The loopback port used by the T3 Code server and Coder app."
  type        = number
  default     = 3773

  validation {
    condition     = var.port >= 1024 && var.port <= 65535 && floor(var.port) == var.port
    error_message = "port must be an integer between 1024 and 65535."
  }
}

variable "t3code_version" {
  description = "T3 Code npm package version to install, or latest."
  type        = string
  default     = "latest"

  validation {
    condition     = var.t3code_version == "latest" || can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+(?:-[0-9A-Za-z.-]+)?$", var.t3code_version))
    error_message = "t3code_version must be latest or a semantic version such as 0.0.28."
  }
}

variable "node_version" {
  description = "Exact Node.js version installed privately for T3 Code."
  type        = string
  default     = "24.18.0"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.node_version))
    error_message = "node_version must be an exact stable semantic version such as 24.18.0."
  }
}

variable "workdir" {
  description = "Optional working directory for T3 Code provider sessions. Defaults to the workspace user's home directory."
  type        = string
  default     = null
}

variable "auto_bootstrap_project" {
  description = "Automatically create a T3 Code project for the configured working directory when one does not exist."
  type        = bool
  default     = true
}

variable "order" {
  description = "The order determines the position of the app in the Coder UI. The lowest order is shown first."
  type        = number
  default     = null
}

variable "group" {
  description = "The name of a group that this app belongs to."
  type        = string
  default     = null
}

variable "icon" {
  description = "Icon shown for the T3 Code app and lifecycle scripts."
  type        = string
  default     = "https://raw.githubusercontent.com/pingdotgg/t3code/ca5f4725ca1dc018d6b9a95835ecf3a6cd8d34f3/assets/prod/logo.svg"
}

variable "pre_install_script" {
  description = "Custom script to run before installing T3 Code."
  type        = string
  default     = null
}

variable "post_install_script" {
  description = "Custom script to run after installing T3 Code."
  type        = string
  default     = null
}

locals {
  module_directory = "$HOME/.coder-modules/coder/t3code"

  install_script = templatefile("${path.module}/scripts/install.sh.tftpl", {
    ARG_NODE_VERSION   = var.node_version
    ARG_T3CODE_VERSION = var.t3code_version
  })

  start_script = templatefile("${path.module}/scripts/start.sh.tftpl", {
    ARG_AUTO_BOOTSTRAP_PROJECT = tostring(var.auto_bootstrap_project)
    ARG_PORT                   = tostring(var.port)
    ARG_WORKDIR_B64            = var.workdir == null ? "" : base64encode(var.workdir)
  })
}

module "coder_utils" {
  source  = "registry.coder.com/coder/coder-utils/coder"
  version = "0.0.1"

  agent_id            = var.agent_id
  module_directory    = local.module_directory
  display_name_prefix = "T3 Code"
  icon                = var.icon
  pre_install_script  = var.pre_install_script
  install_script      = local.install_script
  post_install_script = var.post_install_script
  start_script        = local.start_script
}

resource "coder_app" "t3code" {
  agent_id     = var.agent_id
  slug         = "t3code"
  display_name = "T3 Code"
  url          = "http://localhost:${var.port}"
  icon         = var.icon
  subdomain    = true
  share        = "owner"
  order        = var.order
  group        = var.group

  healthcheck {
    url       = "http://localhost:${var.port}/"
    interval  = 5
    threshold = 12
  }
}

output "scripts" {
  description = "Ordered list of coder exp sync names produced by the T3 Code install and start pipeline."
  value       = module.coder_utils.scripts
}

output "url" {
  description = "Loopback URL used by the T3 Code Coder app."
  value       = coder_app.t3code.url
}
