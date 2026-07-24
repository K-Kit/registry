---
display_name: AI Development on Docker
description: Interactive Docker development workspace with persistent projects, IDEs, AI agents, and orchestration interfaces
icon: ../../../../.icons/docker.svg
verified: false
tags: [docker, ai, ide, claude, codex, opencode]
---

# AI Development on Docker

Create a general-purpose interactive development workspace in an ephemeral
`codercom/example-universal:ubuntu` container. The complete `/home/coder`
directory is stored in a persistent Docker volume, and projects live under
`/home/coder/projects`.

This template is not a Coder Tasks template and does not create a sample
application.

## Included development surfaces

- code-server in the browser
- Cursor and Windsurf desktop launchers
- Selectable JetBrains desktop launchers
- Dotfiles with a manual refresh action
- An owner-only Preview app on a configurable port

Preview reports unhealthy until a server responds on the configured port. A
missing preview server does not fail workspace provisioning.

## Repository setup

The repository URL is optional. When supplied, the template clones it into
`/home/coder/projects` with submodules enabled. HTTPS URLs for
`github.com` and `gitlab.com` use Coder external authentication providers named
`github` and `gitlab`; configure those providers on the deployment before using
private repositories. SSH URLs use the workspace owner's Coder SSH key.

Clone failures block workspace login and remain visible in the startup scripts.
The persisted clone log is:

```text
$HOME/.coder-modules/coder/git-clone/<repository-name>/logs/clone.log
```

## AI agents and interfaces

Claude Code, Codex, and OpenCode are selected by default. Clear the AI-agent
selection to create an IDE-only workspace; this also omits T3 Code and Mux.
Interactive credentials and configuration written below `/home/coder` survive
container recreation.

T3 Code and Mux are selected by default when at least one AI agent is enabled:

- T3 Code provides browser-based sessions for supported coding agents. Opening
  the app creates a fresh 30-day pairing token and embeds it in the `/pair`
  link; pairing credentials are never stored in Terraform state.
- Mux provides parallel agent sessions with isolated project workflows.

The Claude Code, Codex, and OpenCode terminal launchers wait up to 120 seconds
for installation. If installation is not complete, each launcher exits with its
exact persisted log path:

```text
$HOME/.coder-modules/coder/claude-code/logs/install.log
$HOME/.coder-modules/coder-labs/codex/logs/install.log
$HOME/.coder-modules/coder-labs/opencode/logs/install.log
```

Additional troubleshooting logs are stored at:

```text
$HOME/.coder-modules/coder/t3code/logs/
$HOME/.coder-modules/coder/mux/logs/install.log
$HOME/.coder-modules/coder/mux/logs/start.log
$HOME/.coder-modules/coder/mux/logs/mux.log
```

## Coder AI Gateway

AI Gateway is optional and configures Claude Code and Codex through their
registry modules. It requires Coder Premium and Coder 2.30 or newer. Do not
enable it unless AI Gateway is configured on the deployment.

## Prerequisites

- A Linux Coder provisioner with access to a Docker socket
- Coder 2.24 or newer for selectable JetBrains launchers
- Wildcard workspace application access for subdomain-based apps
- Optional GitHub and GitLab external authentication providers named `github`
  and `gitlab`

## Push and verify

From this directory:

```sh
terraform init -upgrade
terraform validate
coder templates push ai-dev
```

Create a workspace with the default selections and verify:

1. Clone `https://github.com/coder/registry`.
2. Open code-server, Cursor, Windsurf, one selected JetBrains IDE, Claude Code,
   Codex, OpenCode, T3 Code, Mux, and Preview.
3. Add a repository file and interactive agent configuration under
   `/home/coder`, restart the workspace, and confirm both persist.
4. Create another workspace with an empty AI-agent selection and confirm that
   Claude Code, Codex, OpenCode, T3 Code, and Mux are absent.

Preview is expected to be unhealthy when no process is listening on its
configured port.
