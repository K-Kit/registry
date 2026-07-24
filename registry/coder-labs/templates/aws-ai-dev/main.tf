terraform {
  required_version = ">= 1.9"

  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.13"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

module "aws_region" {
  source  = "registry.coder.com/coder/aws-region/coder"
  version = "~> 1.0"
  default = "us-east-1"
}

provider "aws" {
  region = module.aws_region.value
}

variable "subnet_id" {
  description = "Optional subnet ID for workspace instances. Leave empty to use the first available subnet in the default VPC."
  type        = string
  default     = ""
}

variable "iam_instance_profile" {
  description = "Optional IAM instance profile name to attach to workspace instances."
  type        = string
  default     = ""
}

variable "assign_public_ip" {
  description = "Assign a public IPv4 address to the workspace instance. Disable this when the subnet has private outbound connectivity."
  type        = bool
  default     = true
}

data "coder_parameter" "instance_type" {
  name         = "instance_type"
  display_name = "Instance type"
  description  = "EC2 instance type used while the workspace is running."
  type         = "string"
  form_type    = "dropdown"
  default      = "t3.large"
  mutable      = false
  order        = 1

  option {
    name  = "2 vCPU, 4 GiB RAM"
    value = "t3.medium"
  }

  option {
    name  = "2 vCPU, 8 GiB RAM"
    value = "t3.large"
  }

  option {
    name  = "4 vCPU, 16 GiB RAM"
    value = "t3.xlarge"
  }

  option {
    name  = "8 vCPU, 32 GiB RAM"
    value = "t3.2xlarge"
  }
}

data "coder_parameter" "home_disk_size" {
  name         = "home_disk_size"
  display_name = "Home disk size"
  description  = "Persistent EBS volume size for /home/coder, in GiB."
  type         = "number"
  form_type    = "slider"
  default      = 50
  mutable      = false
  order        = 2

  validation {
    min = 20
    max = 500
  }
}

data "coder_parameter" "repository_url" {
  name         = "repository_url"
  display_name = "Repository URL"
  description  = "Optional HTTPS or SSH Git repository to clone with submodules into /home/coder/projects. HTTPS GitHub and GitLab URLs use the deployment's external authentication provider."
  type         = "string"
  default      = ""
  mutable      = false
  order        = 10
}

data "coder_parameter" "ai_agents" {
  name         = "ai_agents"
  display_name = "AI agents"
  description  = "AI command-line agents to install. Clear every option for an IDE-only workspace."
  type         = "list(string)"
  form_type    = "multi-select"
  default      = jsonencode(["Claude Code", "Codex", "OpenCode", "Gemini CLI", "Grok CLI"])
  mutable      = false
  order        = 11

  option {
    name  = "Claude Code"
    value = "Claude Code"
    icon  = "/icon/claude.svg"
  }

  option {
    name  = "Codex"
    value = "Codex"
    icon  = "/icon/openai.svg"
  }

  option {
    name  = "OpenCode"
    value = "OpenCode"
    icon  = "/icon/opencode.svg"
  }

  option {
    name  = "Gemini CLI"
    value = "Gemini CLI"
    icon  = "/icon/terminal.svg"
  }

  option {
    name  = "Grok CLI"
    value = "Grok CLI"
    icon  = "/icon/terminal.svg"
  }
}

data "coder_parameter" "ai_interfaces" {
  name         = "ai_interfaces"
  display_name = "AI orchestration interfaces"
  description  = "Browser interfaces to install when at least one AI agent is selected."
  type         = "list(string)"
  form_type    = "multi-select"
  default      = jsonencode(["T3 Code", "Mux"])
  mutable      = false
  order        = 12

  option {
    name  = "T3 Code"
    value = "T3 Code"
    icon  = "/icon/t3code.svg"
  }

  option {
    name  = "Mux"
    value = "Mux"
    icon  = "/icon/mux.svg"
  }
}

data "coder_parameter" "enable_ai_gateway" {
  name         = "enable_ai_gateway"
  display_name = "Coder AI Gateway"
  description  = "Use Coder AI Gateway for Claude Code and Codex. Requires Coder Premium and Coder 2.30 or newer."
  type         = "bool"
  form_type    = "switch"
  default      = false
  mutable      = false
  order        = 13
}

data "coder_parameter" "preview_port" {
  name         = "preview_port"
  display_name = "Preview port"
  description  = "Local port exposed by the owner-only Preview app."
  type         = "number"
  default      = 3000
  mutable      = true
  order        = 14

  validation {
    min = 1
    max = 65535
  }
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

locals {
  projects_dir    = "/home/coder/projects"
  selected_agents = try(jsondecode(data.coder_parameter.ai_agents.value), [])
  selected_interfaces = length(local.selected_agents) == 0 ? [] : try(
    jsondecode(data.coder_parameter.ai_interfaces.value),
    [],
  )
  repository_url = trimspace(data.coder_parameter.repository_url.value)
  has_repository = local.repository_url != ""
  workdir        = try(module.git_clone[0].repo_dir, local.projects_dir)
  t3code_install_script = templatefile("${path.module}/scripts/t3code-install.sh.tftpl", {
    ARG_NODE_VERSION   = "24.18.0"
    ARG_T3CODE_VERSION = "latest"
  })
  t3code_start_script = templatefile("${path.module}/scripts/t3code-start.sh.tftpl", {
    ARG_AUTO_BOOTSTRAP_PROJECT = "true"
    ARG_PAIRING_SECRET_B64     = try(base64encode(random_password.t3code_pairing_secret[0].result), "")
    ARG_PORT                   = "3773"
    ARG_WORKDIR_B64            = base64encode(local.workdir)
  })
  opencode_install_script = templatefile("${path.module}/scripts/opencode-install.sh.tftpl", {
    ARG_OPENCODE_VERSION = "latest"
  })
  gemini_install_script = templatefile("${path.module}/scripts/gemini-install.sh.tftpl", {
    ARG_GEMINI_VERSION = "latest"
    ARG_NODE_VERSION   = "24.18.0"
  })
  grok_install_script = templatefile("${path.module}/scripts/grok-install.sh.tftpl", {
    ARG_GROK_VERSION = "latest"
  })
  mux_install_script = templatefile("${path.module}/scripts/mux-install.sh.tftpl", {
    ARG_MUX_VERSION = "next"
  })
  mux_start_script = templatefile("${path.module}/scripts/mux-start.sh.tftpl", {
    ARG_AUTH_TOKEN  = try(random_password.mux_auth_token[0].result, "")
    ARG_PORT        = "4000"
    ARG_WORKDIR_B64 = base64encode(local.workdir)
  })
}

data "coder_external_auth" "github" {
  count = startswith(local.repository_url, "https://github.com/") ? 1 : 0
  id    = "github"
}

data "coder_external_auth" "gitlab" {
  count = startswith(local.repository_url, "https://gitlab.com/") ? 1 : 0
  id    = "gitlab"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_vpc" "default" {
  count   = var.subnet_id == "" ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = var.subnet_id == "" ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
}

data "aws_subnet" "workspace" {
  id = var.subnet_id != "" ? var.subnet_id : sort(data.aws_subnets.default[0].ids)[0]
}

resource "coder_agent" "main" {
  arch               = "amd64"
  auth               = "aws-instance-identity"
  os                 = "linux"
  connection_timeout = 600

  startup_script = <<-EOT
    #!/bin/bash
    set -euo pipefail

    if [ ! -f "$HOME/.init_done" ]; then
      cp -rT /etc/skel "$HOME"
      touch "$HOME/.init_done"
    fi

    mkdir -p "${local.projects_dir}"

  EOT

  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
  }

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "2_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  display_apps {
    vscode                 = true
    vscode_insiders        = false
    web_terminal           = true
    ssh_helper             = false
    port_forwarding_helper = true
  }
}

module "git_clone" {
  count    = data.coder_workspace.me.start_count > 0 && local.has_repository ? 1 : 0
  source   = "registry.coder.com/coder/git-clone/coder"
  version  = "2.0.2"
  agent_id = coder_agent.main.id
  url      = local.repository_url
  base_dir = local.projects_dir
  extra_args = [
    "--recurse-submodules",
  ]
}

module "dotfiles" {
  count         = data.coder_workspace.me.start_count
  source        = "registry.coder.com/coder/dotfiles/coder"
  version       = "1.4.2"
  agent_id      = coder_agent.main.id
  manual_update = true
  order         = 90
}

module "code_server" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/code-server/coder"
  version  = "1.5.2"
  agent_id = coder_agent.main.id
  folder   = local.workdir
  group    = "Development"
  order    = 1

  settings = {
    "workbench.colorTheme" = "Default Dark Modern"
  }
}

module "cursor" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/cursor/coder"
  version  = "1.4.1"
  agent_id = coder_agent.main.id
  folder   = local.workdir
  group    = "Development"
  order    = 2
}

module "windsurf" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/windsurf/coder"
  version  = "1.3.1"
  agent_id = coder_agent.main.id
  folder   = local.workdir
  group    = "Development"
  order    = 3
}

module "jetbrains" {
  count                 = data.coder_workspace.me.start_count
  source                = "registry.coder.com/coder/jetbrains/coder"
  version               = "1.4.0"
  agent_id              = coder_agent.main.id
  agent_name            = "main"
  folder                = local.workdir
  group                 = "Development"
  coder_app_order       = 4
  coder_parameter_order = 10
}

module "claude_code" {
  count             = data.coder_workspace.me.start_count > 0 && contains(local.selected_agents, "Claude Code") ? 1 : 0
  source            = "registry.coder.com/coder/claude-code/coder"
  version           = "5.2.0"
  agent_id          = coder_agent.main.id
  workdir           = local.workdir
  enable_ai_gateway = data.coder_parameter.enable_ai_gateway.value
}

module "codex" {
  count             = data.coder_workspace.me.start_count > 0 && contains(local.selected_agents, "Codex") ? 1 : 0
  source            = "registry.coder.com/coder-labs/codex/coder"
  version           = "5.3.0"
  agent_id          = coder_agent.main.id
  workdir           = local.workdir
  enable_ai_gateway = data.coder_parameter.enable_ai_gateway.value
}

module "opencode" {
  count  = data.coder_workspace.me.start_count > 0 && contains(local.selected_agents, "OpenCode") ? 1 : 0
  source = "registry.coder.com/coder/coder-utils/coder"

  version = "0.0.1"

  agent_id            = coder_agent.main.id
  module_directory    = "$HOME/.coder-modules/coder-labs/opencode"
  display_name_prefix = "OpenCode"
  icon                = "/icon/opencode.svg"
  install_script      = local.opencode_install_script
}

module "gemini" {
  count  = data.coder_workspace.me.start_count > 0 && contains(local.selected_agents, "Gemini CLI") ? 1 : 0
  source = "registry.coder.com/coder/coder-utils/coder"

  version = "0.0.1"

  agent_id            = coder_agent.main.id
  module_directory    = "$HOME/.coder-modules/coder-labs/gemini-cli"
  display_name_prefix = "Gemini CLI"
  icon                = "/icon/terminal.svg"
  install_script      = local.gemini_install_script
}

module "grok" {
  count  = data.coder_workspace.me.start_count > 0 && contains(local.selected_agents, "Grok CLI") ? 1 : 0
  source = "registry.coder.com/coder/coder-utils/coder"

  version = "0.0.1"

  agent_id            = coder_agent.main.id
  module_directory    = "$HOME/.coder-modules/coder-labs/grok-cli"
  display_name_prefix = "Grok CLI"
  icon                = "/icon/terminal.svg"
  install_script      = local.grok_install_script
}

resource "coder_app" "claude_code" {
  count        = data.coder_workspace.me.start_count > 0 && contains(local.selected_agents, "Claude Code") ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "claude-code"
  display_name = "Claude Code"
  icon         = "/icon/claude.svg"
  group        = "AI Agents"
  order        = 11
  open_in      = "slim-window"
  command      = <<-EOT
    #!/bin/bash
    set -e

    log_path="$HOME/.coder-modules/coder/claude-code/logs/install.log"
    deadline=$((SECONDS + 120))
    until command -v claude >/dev/null 2>&1; do
      if [ "$SECONDS" -ge "$deadline" ]; then
        printf 'Claude Code was not installed within 120 seconds. Installation log: %s\n' "$log_path" >&2
        exit 1
      fi
      sleep 2
    done

    cd "${local.workdir}"
    exec claude
  EOT
}

resource "coder_app" "codex" {
  count        = data.coder_workspace.me.start_count > 0 && contains(local.selected_agents, "Codex") ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "codex"
  display_name = "Codex"
  icon         = "/icon/openai.svg"
  group        = "AI Agents"
  order        = 12
  open_in      = "slim-window"
  command      = <<-EOT
    #!/bin/bash
    set -e

    log_path="$HOME/.coder-modules/coder-labs/codex/logs/install.log"
    deadline=$((SECONDS + 120))
    until command -v codex >/dev/null 2>&1; do
      if [ "$SECONDS" -ge "$deadline" ]; then
        printf 'Codex was not installed within 120 seconds. Installation log: %s\n' "$log_path" >&2
        exit 1
      fi
      sleep 2
    done

    cd "${local.workdir}"
    exec codex
  EOT
}

resource "coder_app" "opencode" {
  count        = data.coder_workspace.me.start_count > 0 && contains(local.selected_agents, "OpenCode") ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "opencode-cli"
  display_name = "OpenCode CLI"
  icon         = "/icon/opencode.svg"
  group        = "AI Agents"
  order        = 14
  open_in      = "slim-window"
  command      = <<-EOT
    #!/bin/bash
    set -e

    export PATH="$HOME/.opencode/bin:$PATH"
    log_path="$HOME/.coder-modules/coder-labs/opencode/logs/install.log"
    deadline=$((SECONDS + 120))
    until command -v opencode >/dev/null 2>&1; do
      if [ "$SECONDS" -ge "$deadline" ]; then
        printf 'OpenCode was not installed within 120 seconds. Installation log: %s\n' "$log_path" >&2
        exit 1
      fi
      sleep 2
    done

    cd "${local.workdir}"
    exec opencode
  EOT
}

resource "coder_app" "gemini" {
  count        = data.coder_workspace.me.start_count > 0 && contains(local.selected_agents, "Gemini CLI") ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "gemini-cli"
  display_name = "Gemini CLI"
  icon         = "/icon/terminal.svg"
  group        = "AI Agents"
  order        = 15
  open_in      = "slim-window"
  command      = <<-EOT
    #!/bin/bash
    set -e

    export PATH="$HOME/.coder-modules/coder-labs/gemini-cli/runtime/node_modules/.bin:$HOME/.local/bin:$PATH"
    log_path="$HOME/.coder-modules/coder-labs/gemini-cli/logs/install.log"
    deadline=$((SECONDS + 120))
    until command -v gemini >/dev/null 2>&1; do
      if [ "$SECONDS" -ge "$deadline" ]; then
        printf 'Gemini CLI was not installed within 120 seconds. Installation log: %s\n' "$log_path" >&2
        exit 1
      fi
      sleep 2
    done

    cd "${local.workdir}"
    exec gemini
  EOT
}

resource "coder_app" "grok" {
  count        = data.coder_workspace.me.start_count > 0 && contains(local.selected_agents, "Grok CLI") ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "grok-cli"
  display_name = "Grok CLI"
  icon         = "/icon/terminal.svg"
  group        = "AI Agents"
  order        = 16
  open_in      = "slim-window"
  command      = <<-EOT
    #!/bin/bash
    set -e

    export PATH="$HOME/.coder-modules/coder-labs/grok-cli/bin:$HOME/.local/bin:$PATH"
    log_path="$HOME/.coder-modules/coder-labs/grok-cli/logs/install.log"
    deadline=$((SECONDS + 120))
    until command -v grok >/dev/null 2>&1; do
      if [ "$SECONDS" -ge "$deadline" ]; then
        printf 'Grok CLI was not installed within 120 seconds. Installation log: %s\n' "$log_path" >&2
        exit 1
      fi
      sleep 2
    done

    cd "${local.workdir}"
    exec grok
  EOT
}

resource "random_password" "t3code_pairing_secret" {
  count   = contains(local.selected_interfaces, "T3 Code") ? 1 : 0
  length  = 32
  special = false
}

resource "coder_env" "t3code_pairing_secret" {
  count    = contains(local.selected_interfaces, "T3 Code") ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "T3CODE_PAIRING_SECRET"
  value    = random_password.t3code_pairing_secret[count.index].result
}

module "t3code" {
  count  = data.coder_workspace.me.start_count > 0 && contains(local.selected_interfaces, "T3 Code") ? 1 : 0
  source = "registry.coder.com/coder/coder-utils/coder"

  version = "0.0.1"

  agent_id            = coder_agent.main.id
  module_directory    = "$HOME/.coder-modules/coder/t3code"
  display_name_prefix = "T3 Code"
  icon                = "/icon/t3code.svg"
  install_script      = local.t3code_install_script
  start_script        = local.t3code_start_script
}

resource "coder_app" "t3code" {
  count        = data.coder_workspace.me.start_count > 0 && contains(local.selected_interfaces, "T3 Code") ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "t3code"
  display_name = "T3 Code"
  url          = "http://localhost:3773/pair#token=${random_password.t3code_pairing_secret[0].result}"
  icon         = "/icon/t3code.svg"
  subdomain    = true
  share        = "owner"
  group        = "AI Orchestration"
  order        = 20

  healthcheck {
    url       = "http://localhost:3773/"
    interval  = 5
    threshold = 12
  }
}

resource "random_password" "mux_auth_token" {
  count   = data.coder_workspace.me.start_count > 0 && contains(local.selected_interfaces, "Mux") ? 1 : 0
  length  = 32
  special = false
}

module "mux" {
  count  = data.coder_workspace.me.start_count > 0 && contains(local.selected_interfaces, "Mux") ? 1 : 0
  source = "registry.coder.com/coder/coder-utils/coder"

  version = "0.0.1"

  agent_id            = coder_agent.main.id
  module_directory    = "$HOME/.coder-modules/coder/mux"
  display_name_prefix = "Mux"
  icon                = "/icon/mux.svg"
  install_script      = local.mux_install_script
  start_script        = local.mux_start_script
}

resource "coder_app" "mux" {
  count        = data.coder_workspace.me.start_count > 0 && contains(local.selected_interfaces, "Mux") ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "mux"
  display_name = "Mux"
  url          = "http://localhost:4000?token=${random_password.mux_auth_token[0].result}"
  icon         = "/icon/mux.svg"
  subdomain    = false
  share        = "owner"
  group        = "AI Orchestration"
  order        = 21

  healthcheck {
    url       = "http://localhost:4000/health"
    interval  = 5
    threshold = 12
  }
}

resource "coder_app" "preview" {
  agent_id     = coder_agent.main.id
  slug         = "preview"
  display_name = "Preview"
  icon         = "/icon/widgets.svg"
  url          = "http://localhost:${data.coder_parameter.preview_port.value}"
  share        = "owner"
  subdomain    = true
  open_in      = "tab"
  group        = "Development"
  order        = 5

  healthcheck {
    url       = "http://localhost:${data.coder_parameter.preview_port.value}/"
    interval  = 5
    threshold = 6
  }
}

resource "aws_ebs_volume" "home" {
  availability_zone = data.aws_subnet.workspace.availability_zone
  encrypted         = true
  size              = data.coder_parameter.home_disk_size.value
  type              = "gp3"

  tags = {
    Name                               = "coder-${data.coder_workspace.me.id}-home"
    "coder.owner"                      = data.coder_workspace_owner.me.name
    "coder.owner_id"                   = data.coder_workspace_owner.me.id
    "coder.workspace_id"               = data.coder_workspace.me.id
    "coder.workspace_name_at_creation" = data.coder_workspace.me.name
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "aws_instance" "workspace" {
  count                       = data.coder_workspace.me.start_count
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = data.coder_parameter.instance_type.value
  subnet_id                   = data.aws_subnet.workspace.id
  associate_public_ip_address = var.assign_public_ip
  iam_instance_profile        = var.iam_instance_profile != "" ? var.iam_instance_profile : null
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/cloud-init/startup.sh.tftpl", {
    INIT_SCRIPT_B64 = base64encode(coder_agent.main.init_script)
    HOME_VOLUME_ID  = aws_ebs_volume.home.id
  })

  root_block_device {
    encrypted   = true
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name                               = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
    "coder.owner"                      = data.coder_workspace_owner.me.name
    "coder.owner_id"                   = data.coder_workspace_owner.me.id
    "coder.workspace_id"               = data.coder_workspace.me.id
    "coder.workspace_name_at_creation" = data.coder_workspace.me.name
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_volume_attachment" "home" {
  count       = data.coder_workspace.me.start_count
  device_name = "/dev/sdh"
  instance_id = aws_instance.workspace[count.index].id
  volume_id   = aws_ebs_volume.home.id
}

resource "coder_metadata" "workspace" {
  count       = data.coder_workspace.me.start_count
  resource_id = aws_instance.workspace[count.index].id

  item {
    key   = "region"
    value = module.aws_region.value
  }

  item {
    key   = "availability zone"
    value = data.aws_subnet.workspace.availability_zone
  }

  item {
    key   = "instance type"
    value = data.coder_parameter.instance_type.value
  }

  item {
    key   = "image"
    value = data.aws_ami.ubuntu.name
  }
}

resource "coder_metadata" "home" {
  resource_id = aws_ebs_volume.home.id

  item {
    key   = "mount point"
    value = "/home/coder"
  }

  item {
    key   = "size"
    value = "${data.coder_parameter.home_disk_size.value} GiB"
  }
}
