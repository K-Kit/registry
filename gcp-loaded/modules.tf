
variable "claude_code_oauth_token" {
  description = "OAuth token passed to Claude Code via the CLAUDE_CODE_OAUTH_TOKEN env var. Generate one with `claude setup-token`."
  type        = string
  default     = ""
  sensitive   = true
}
module "claude-code" {
  count                   = data.coder_workspace.me.start_count
  source                  = "registry.coder.com/coder/claude-code/coder"
  version                 = "5.2.0"
  agent_id                = coder_agent.main.id
  anthropic_api_key       = ""
  claude_binary_path      = "$HOME/.local/bin"
  claude_code_oauth_token = var.claude_code_oauth_token
  claude_code_version     = "latest"
  disable_autoupdater     = false
  enable_ai_gateway       = false
  icon                    = "/icon/claude.svg"
  install_claude_code     = true
  mcp                     = ""
  model                   = ""
  post_install_script     = null
  pre_install_script      = null
  workdir                 = null
}


variable "openai_api_key" {
  description = "OpenAI API key for Codex CLI."
  type        = string
  sensitive   = true
  default     = ""
}
module "codex" {
  count                  = data.coder_workspace.me.start_count
  source                 = "registry.coder.com/coder-labs/codex/coder"
  version                = "5.3.0"
  agent_id               = coder_agent.main.id
  base_config_toml       = ""
  codex_version          = "latest"
  enable_ai_gateway      = false
  icon                   = "/icon/openai.svg"
  install_codex          = true
  mcp                    = ""
  model_reasoning_effort = ""
  openai_api_key         = var.openai_api_key
  post_install_script    = null
  pre_install_script     = null
  workdir                = null
}

module "cursor" {
  count       = data.coder_workspace.me.start_count
  source      = "registry.coder.com/coder/cursor/coder"
  version     = "1.4.1"
  agent_id    = coder_agent.main.id
  folder      = ""
  mcp         = ""
  open_recent = false
}

module "code-server" {
  count                   = data.coder_workspace.me.start_count
  source                  = "registry.coder.com/coder/code-server/coder"
  version                 = "1.5.0"
  agent_id                = coder_agent.main.id
  additional_args         = ""
  auto_install_extensions = false
  extensions_dir          = ""
  folder                  = ""
  install_version         = ""
  offline                 = false
  open_in                 = "slim-window"
  port                    = 13337
  use_cached              = false
  use_cached_extensions   = false
  workspace               = ""
}

module "jetbrains" {
  count              = data.coder_workspace.me.start_count
  source             = "registry.coder.com/coder/jetbrains/coder"
  version            = "1.4.0"
  agent_id           = coder_agent.main.id
  agent_name         = null
  channel            = "release"
  download_base_link = "https://download.jetbrains.com"
  folder             = "/home/coder"
  major_version      = "latest"
  releases_base_link = "https://data.services.jetbrains.com"
  tooltip            = "You need to install [JetBrains Toolbox App](https://www.jetbrains.com/toolbox-app/) to use this button."
}

module "dotfiles" {
  count                   = data.coder_workspace.me.start_count
  source                  = "registry.coder.com/coder/dotfiles/coder"
  version                 = "1.4.2"
  agent_id                = coder_agent.main.id
  default_dotfiles_branch = ""
  default_dotfiles_uri    = ""
  description             = "Enter a URL for a [dotfiles repository](https://dotfiles.github.io) to personalize your workspace. Use an SSH URL (e.g. `git@host:user/repo`) if your Git provider restricts HTTPS cloning."
  dotfiles_branch         = null
  dotfiles_uri            = null
  manual_update           = false
  post_clone_script       = null
  user                    = null
}

module "filebrowser" {
  count         = data.coder_workspace.me.start_count
  source        = "registry.coder.com/coder/filebrowser/coder"
  version       = "1.1.5"
  agent_id      = coder_agent.main.id
  agent_name    = null
  database_path = "filebrowser.db"
  folder        = "~"
  port          = 13339
}

module "personalize" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/personalize/coder"
  version  = "1.0.32"
  agent_id = coder_agent.main.id
  path     = "~/personalize"
}

module "git-config" {
  count                 = data.coder_workspace.me.start_count
  source                = "registry.coder.com/coder/git-config/coder"
  version               = "1.0.33"
  agent_id              = coder_agent.main.id
  allow_email_change    = false
  allow_username_change = true
}

module "git-commit-signing" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/git-commit-signing/coder"
  version  = "1.0.32"
  agent_id = coder_agent.main.id
}

module "kasmvnc" {
  count               = data.coder_workspace.me.start_count
  source              = "registry.coder.com/coder/kasmvnc/coder"
  version             = "1.3.0"
  agent_id            = coder_agent.main.id
  desktop_environment = "xfce"
  kasm_version        = "1.4.0"
  port                = 6800
}

module "jupyterlab" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/jupyterlab/coder"
  version  = "1.2.2"
  agent_id = coder_agent.main.id
  config   = "{}"
  port     = 19999
}

module "vscode-desktop" {
  count       = data.coder_workspace.me.start_count
  source      = "registry.coder.com/coder/vscode-desktop/coder"
  version     = "1.2.1"
  agent_id    = coder_agent.main.id
  folder      = ""
  open_recent = false
}
