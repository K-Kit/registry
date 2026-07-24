---
display_name: T3 Code
description: Run the T3 Code web interface for Codex, Claude Code, Cursor, and OpenCode
icon: ../../../../.icons/t3code.svg
verified: false
tags: [ide, ai, agent, codex, claude, opencode]
---

# T3 Code

Run [T3 Code](https://github.com/pingdotgg/t3code), a web interface for coding agents, inside a Coder workspace. The module installs a private Node.js runtime and T3 Code package, starts the server on IPv4 loopback, and exposes it through an owner-only Coder app.

Install and authenticate at least one supported provider CLI before using T3 Code. T3 Code currently supports Codex, Claude Code, Cursor, and OpenCode.

Set `pairing_secret` to a secret of at least 12 characters when clients need a stable pairing credential. The module passes it through T3 Code's bootstrap file descriptor so it does not appear in the server command line. Leave it empty to use T3 Code-generated pairing tokens.

```tf
module "t3code" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/k-kit/t3code/coder"
  version  = "1.1.1"
  agent_id = coder_agent.main.id
}
```

## Open a project automatically

```tf
module "t3code" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/k-kit/t3code/coder"
  version  = "1.1.1"
  agent_id = coder_agent.main.id
  workdir  = "/home/coder/project"
}
```

T3 Code state, its private runtime, materialized scripts, and lifecycle logs are stored under `~/.coder-modules/k-kit/t3code/`. Check `logs/install.log`, `logs/start.log`, and `logs/t3code.log` when troubleshooting.
