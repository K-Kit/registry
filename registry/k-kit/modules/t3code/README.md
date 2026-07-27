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

By default, `t3code_version = "latest"` resolves the newest public [K-Kit T3 Code release](https://github.com/K-Kit/t3code/releases). The current `0.0.28-k-kit.1` package is built from commit [`7c84ad2c`](https://github.com/K-Kit/t3code/commit/7c84ad2cb3da3e78ee578a14fce4bf2f97e138fb) and includes the OMP/Pi websocket serialization fix. Set an exact `-k-kit.N` version to pin a K-Kit release, or another exact semantic version to install the official `t3` npm package. Provisioning fails with a clear error when `latest` cannot be resolved instead of silently treating a stale installation as current.

The workspace image must provide Python 3, Make, and a C++ compiler. The module does not install operating-system packages at runtime; install `build-essential` and `python3` in Debian or Ubuntu images before the Coder agent starts.

Set `pairing_secret` to a secret of at least 12 characters when clients need a stable pairing credential. The module passes it through T3 Code's bootstrap file descriptor so it does not appear in the server command line. Leave it empty to use T3 Code-generated pairing tokens.

```tf
module "t3code" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/k-kit/t3code/coder"
  version  = "1.1.3"
  agent_id = coder_agent.main.id
}
```

## Open a project automatically

```tf
module "t3code" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/k-kit/t3code/coder"
  version  = "1.1.3"
  agent_id = coder_agent.main.id
  workdir  = "/home/coder/project"
}
```

T3 Code state, its private runtime, materialized scripts, and lifecycle logs are stored under `~/.coder-modules/k-kit/t3code/`. Check `logs/install.log`, `logs/start.log`, and `logs/t3code.log` when troubleshooting.
