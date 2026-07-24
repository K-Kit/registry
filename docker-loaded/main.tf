terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

provider "coder" {}

variable "docker_socket" {
  description = "Optional Docker socket URI. Leave empty to use the Docker provider default."
  type        = string
  default     = ""
}

provider "docker" {
  host = var.docker_socket != "" ? var.docker_socket : null
}

data "coder_parameter" "container_image" {
  name         = "container_image"
  display_name = "Container Image"
  description  = "Debian or Ubuntu base image used to build the workspace image. It must support apt and the amd64 or arm64 architecture."
  type         = "string"
  default      = "codercom/enterprise-base:ubuntu"
  mutable      = false
  order        = 1
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

locals {
  linux_user = "coder"
}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"
  startup_script = templatefile("${path.module}/scripts/install-optional-tools.sh.tftpl", {
    ARG_INSTALL_GEMINI_CLI            = tostring(data.coder_parameter.install_gemini_cli.value)
    ARG_INSTALL_OH_MY_CLAUDE_SISYPHUS = tostring(data.coder_parameter.install_oh_my_claude_sisyphus.value)
    ARG_INSTALL_OH_MY_CODEX           = tostring(data.coder_parameter.install_oh_my_codex.value)
    ARG_INSTALL_OH_MY_OPENAGENT       = tostring(data.coder_parameter.install_oh_my_openagent.value)
    ARG_INSTALL_OPENCODE_CLI          = tostring(data.coder_parameter.install_opencode_cli.value)
  })

  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
  }

  metadata {
    key          = "cpu"
    display_name = "CPU Usage"
    interval     = 10
    timeout      = 1
    script       = "coder stat cpu"
  }

  metadata {
    key          = "memory"
    display_name = "Memory Usage"
    interval     = 10
    timeout      = 1
    script       = "coder stat mem"
  }

  metadata {
    key          = "disk"
    display_name = "Home Disk"
    interval     = 60
    timeout      = 1
    script       = "coder stat disk --path $${HOME}"
  }
}

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace.me.id}-home"

  lifecycle {
    ignore_changes = all
  }

  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }

  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }

  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }

  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

resource "docker_image" "workspace" {
  name = "coder-${data.coder_workspace.me.id}:latest"

  build {
    context = "${path.module}/build"
    build_args = {
      BASE_IMAGE = data.coder_parameter.container_image.value
    }
  }

  triggers = {
    dir_sha1 = sha1(join("", [for file in fileset(path.module, "build/*") : filesha1("${path.module}/${file}")]))
  }
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count

  image    = docker_image.workspace.image_id
  name     = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
  hostname = data.coder_workspace.me.name
  init     = true

  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  volumes {
    container_path = "/home/${local.linux_user}"
    volume_name    = docker_volume.home.name
    read_only      = false
  }

  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }

  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }

  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }

  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
}

resource "coder_metadata" "workspace" {
  count       = data.coder_workspace.me.start_count
  resource_id = docker_container.workspace[count.index].id

  item {
    key   = "type"
    value = "Docker container"
  }

  item {
    key   = "image"
    value = data.coder_parameter.container_image.value
  }
}
