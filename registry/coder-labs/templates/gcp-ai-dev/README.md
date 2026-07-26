---
display_name: AI Development on GCP
description: Interactive Compute Engine development workspace with persistent home storage, IDEs, AI agents, and orchestration interfaces
icon: ../../../../.icons/gcp.svg
verified: false
tags: [gcp, compute-engine, ai, ide, claude, codex, opencode, openchamber]
---

# AI Development on GCP

Create a general-purpose interactive development workspace on an ephemeral
Ubuntu 24.04 Compute Engine VM. A separate balanced Persistent Disk stores the
complete `/home/coder` directory, with projects under `/home/coder/projects`.

This is the Google Cloud infrastructure variant of
[AI Development on Docker](../ai-dev). It preserves the same development
surfaces and selectable AI tooling without turning the workspace into a Coder
Tasks template or sample application.

## Development experience

The template provides code-server, Cursor, Windsurf, selectable JetBrains IDEs,
manual dotfiles refresh, and an owner-only Preview app. Preview remains unhealthy
until a process listens on the configured port; this does not fail provisioning.
New workspaces default to stopping automatically after two hours. Owners can
adjust the schedule when the deployment allows user-defined autostop settings.

An optional repository is cloned with submodules into `/home/coder/projects`.
GitHub and GitLab HTTPS repositories use Coder external authentication providers
named `github` and `gitlab`. Clone and installation failures remain visible as
startup failures, with their logs persisted below `$HOME/.coder-modules`.

Claude Code, Codex, OpenCode, Gemini CLI, and Grok CLI are enabled by default.
Clearing the AI-agent selection creates an IDE-only workspace and omits T3 Code
and Mux. OpenCode opens in the browser through an owner-only OpenChamber web app.
T3 Code uses a corrected npm 12-compatible lifecycle and opens as an owner-only
web app. Mux provides parallel isolated agent workflows. Interactive credentials
and configuration persist on the home disk. Grok CLI supports
`grok login --device-auth` for remote authentication.

Optional Coder AI Gateway integration for Claude Code and Codex requires Coder
Premium and Coder 2.30 or newer.

## Architecture

The workspace creates a balanced Persistent Disk in the selected zone and
creates a Compute Engine VM only while the workspace is running. Stopping the
workspace deletes the VM and its boot disk; restarting creates a fresh VM and
remounts the existing home disk. Deleting the workspace deletes the home disk.

The Coder agent authenticates with Google instance identity. No inbound
workspace ports are required, but the VM needs outbound HTTPS access to the Coder
deployment, package registries, and selected Git hosts.

## Prerequisites

- A Google Cloud project with the Compute Engine API enabled
- Google credentials available to the Coder provisioner with permissions to
  read Ubuntu images and manage instances and persistent disks
- The default VPC, or configured `network` and optional `subnetwork` template
  variables
- A Compute Engine service account that the provisioner can attach; the project
  default service account is used when none is specified
- Outbound network connectivity, using either a public IP or private NAT/egress
- Coder 2.30 or newer for coordinated startup scripts and selectable JetBrains
  launchers
- Wildcard workspace application access for subdomain-based apps
- Optional GitHub and GitLab external authentication providers named `github`
  and `gitlab`

The VM receives the `cloud-platform` OAuth scope. Restrict the attached service
account's IAM roles according to the deployment's security model.

## Push and verify

From the repository root:

```sh
terraform -chdir=registry/coder-labs/templates/gcp-ai-dev init -upgrade
terraform -chdir=registry/coder-labs/templates/gcp-ai-dev validate
coder templates push gcp-ai-dev -d registry/coder-labs/templates/gcp-ai-dev
coder templates edit gcp-ai-dev --default-ttl 2h
```

Create a default workspace, clone `https://github.com/coder/registry`, and verify
the IDEs, OpenCode in OpenChamber, the other four AI agents, T3 Code, Mux, and
Preview. Add files under
`/home/coder`, stop and restart the workspace, and confirm they persist. Finally,
create an IDE-only workspace and confirm that all optional AI resources are
absent.
