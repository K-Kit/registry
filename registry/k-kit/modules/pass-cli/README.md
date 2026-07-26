---
display_name: Proton Pass CLI
description: Install and authenticate the Proton Pass command-line interface in a Coder workspace
icon: ../../../../.icons/proton-pass.svg
verified: false
tags: [integration, proton, pass, secrets]
---

# Proton Pass CLI

Install the official [Proton Pass CLI](https://protonpass.github.io/pass-cli/) (`pass-cli`) in a Coder workspace. The module follows Proton's stable release track by default, keeps the binary in the workspace user's local bin directory, and makes it available in future shell sessions.

The workspace image must provide `curl` and `jq`, which are required by Proton's official installer.

```tf
module "pass_cli" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/k-kit/pass-cli/coder"
  version  = "1.0.0"
  agent_id = coder_agent.main.id
}
```

## Authentication

Without credentials, run `pass-cli login` in the workspace and open the displayed URL to complete Proton's web authentication flow. The resulting session is stored locally and persists until logout.

For automated workspaces, create a scoped [personal access token](https://protonpass.github.io/pass-cli/commands/personal-access-token/) and pass it as a sensitive Terraform value. The module exposes it through Proton's documented `PROTON_PASS_PERSONAL_ACCESS_TOKEN` environment variable and signs in non-interactively when no active session exists.

```tf
variable "proton_pass_personal_access_token" {
  description = "Scoped Proton Pass personal access token."
  type        = string
  sensitive   = true
}

module "pass_cli" {
  count                 = data.coder_workspace.me.start_count
  source                = "registry.coder.com/k-kit/pass-cli/coder"
  version               = "1.0.0"
  agent_id              = coder_agent.main.id
  personal_access_token = var.proton_pass_personal_access_token
}
```

On Linux, Proton Pass uses the kernel keyring by default and does not require D-Bus. If the workspace environment cannot access the kernel keyring, set `PROTON_PASS_KEY_PROVIDER=fs` before logging in; filesystem-backed key storage is less secure and should only be used when the default provider is unavailable.

## Release track and custom scripts

Set `install_channel = "beta"` to follow Proton's beta release track. Custom pre-install and post-install scripts are orchestrated around installation with `coder-utils`.

```tf
module "pass_cli" {
  count               = data.coder_workspace.me.start_count
  source              = "registry.coder.com/k-kit/pass-cli/coder"
  version             = "1.0.0"
  agent_id            = coder_agent.main.id
  install_channel     = "beta"
  post_install_script = <<-EOT
    pass-cli info
  EOT
}
```

Materialized scripts and lifecycle logs are stored under `~/.coder-modules/k-kit/pass-cli/`. Check `logs/install.log` when troubleshooting installation or authentication.
