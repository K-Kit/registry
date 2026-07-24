variable "claude_code_oauth_token" {
  description = "OAuth token passed to Claude Code via CLAUDE_CODE_OAUTH_TOKEN."
  type        = string
  default     = ""
  sensitive   = true
}

variable "openai_api_key" {
  description = "OpenAI API key passed to Codex CLI."
  type        = string
  default     = ""
  sensitive   = true
}

module "code_server" {
  count   = data.coder_workspace.me.start_count
  source  = "registry.coder.com/coder/code-server/coder"
  version = "1.5.2"

  agent_id = coder_agent.main.id
  folder   = "$HOME"
  port     = 13337
}

module "claude_code" {
  count   = data.coder_workspace.me.start_count
  source  = "registry.coder.com/coder/claude-code/coder"
  version = "5.2.0"

  agent_id                = coder_agent.main.id
  claude_binary_path      = "$HOME/.local/bin"
  claude_code_oauth_token = var.claude_code_oauth_token
  claude_code_version     = "latest"
  install_claude_code     = true
}

module "codex" {
  count   = data.coder_workspace.me.start_count
  source  = "registry.coder.com/coder-labs/codex/coder"
  version = "5.3.0"

  agent_id       = coder_agent.main.id
  codex_version  = "latest"
  install_codex  = true
  openai_api_key = var.openai_api_key
}

module "dotfiles" {
  count   = data.coder_workspace.me.start_count
  source  = "registry.coder.com/coder/dotfiles/coder"
  version = "1.4.2"

  agent_id                = coder_agent.main.id
  manual_update           = false
  default_dotfiles_uri    = ""
  default_dotfiles_branch = ""
}

module "filebrowser" {
  count   = data.coder_workspace.me.start_count
  source  = "registry.coder.com/coder/filebrowser/coder"
  version = "1.1.5"

  agent_id      = coder_agent.main.id
  database_path = "$HOME/.coder-modules/coder/filebrowser/filebrowser.db"
  folder        = "$HOME"
  port          = 13339
}

module "git_config" {
  count   = data.coder_workspace.me.start_count
  source  = "registry.coder.com/coder/git-config/coder"
  version = "1.0.33"

  agent_id              = coder_agent.main.id
  allow_email_change    = false
  allow_username_change = true
}

module "git_commit_signing" {
  count   = data.coder_workspace.me.start_count
  source  = "registry.coder.com/coder/git-commit-signing/coder"
  version = "1.0.32"

  agent_id = coder_agent.main.id
}

module "jupyterlab" {
  count   = data.coder_workspace.me.start_count
  source  = "registry.coder.com/coder/jupyterlab/coder"
  version = "1.2.2"

  agent_id = coder_agent.main.id
  config   = "{}"
  port     = 19999
}

module "personalize" {
  count   = data.coder_workspace.me.start_count
  source  = "registry.coder.com/coder/personalize/coder"
  version = "1.0.32"

  agent_id = coder_agent.main.id
  path     = "$HOME/personalize"
}

