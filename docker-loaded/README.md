---
display_name: Docker Loaded Development Environment
description: Provision Docker containers with persistent home volumes and a loaded set of development and AI tools
icon: ../.icons/docker.svg
verified: false
tags: [docker, container, linux, ai]
---

# Docker Loaded Development Environment

Provision a Docker container as a Coder workspace with a persistent home volume, browser and desktop IDEs, AI coding CLIs, JupyterLab, file management, personalization, and T3 Code.

## Prerequisites

The Coder provisioner must be able to reach a Docker daemon. By default, the Docker provider uses the local Docker socket; set `docker_socket` when the daemon is exposed at another URI. The provisioner also needs outbound network access to build the workspace image and download module dependencies.

The selected container image must be based on Debian or Ubuntu, support `apt`, and support the provisioner's CPU architecture. The default is `codercom/enterprise-base:ubuntu`.

## Architecture

The template builds a workspace image containing shared prerequisites before any Coder module starts. Each running workspace gets an ephemeral Docker container and a persistent Docker volume mounted at `/home/coder`. Stopping a workspace removes the container while preserving the home volume; deleting the workspace removes its Terraform-managed resources.

The workspace includes Claude Code, Codex, Cursor, code-server, JetBrains Gateway, dotfiles, File Browser, personalization, Git configuration and commit signing, KasmVNC, JupyterLab, VS Code Desktop, and T3 Code. T3 Code is exposed as an owner-only web app for the installed Codex, Claude Code, Cursor, and OpenCode providers.

Set the sensitive template variable `t3code_pairing_secret` to a secret of at least 12 characters to use a stable pairing credential. The secret is delivered to T3 Code through its one-time bootstrap file descriptor rather than a command-line argument. Leave it empty to use T3 Code-generated pairing tokens.

Optional workspace parameters can install Gemini CLI, OpenCode CLI, Oh My Codex, Oh My Claude, and Oh My OpenAgent. Installer output is written to `~/.coder-modules/coder/docker-loaded/logs/install-optional-tools.log`.

Oh My OpenAgent is installed non-interactively with provider integrations and authentication skipped. Run its installer again inside the workspace with the subscription flags appropriate for your accounts if you want provider-specific model configuration.

> [!IMPORTANT]
> The persistent home volume intentionally outlives container restarts. Changing the container image does not replace files already stored in `/home/coder`.
