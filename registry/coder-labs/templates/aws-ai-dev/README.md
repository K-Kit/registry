---
display_name: AI Development on AWS
description: Interactive EC2 development workspace with persistent EBS home storage, IDEs, AI agents, and orchestration interfaces
icon: ../../../../.icons/aws.svg
verified: false
tags: [aws, ec2, ai, ide, claude, codex, opencode]
---

# AI Development on AWS

Create a general-purpose interactive development workspace on an ephemeral
Ubuntu 24.04 EC2 instance. A separate encrypted EBS volume persists the complete
`/home/coder` directory, with projects stored under `/home/coder/projects`.

This is the AWS infrastructure variant of [AI Development on Docker](../ai-dev).
It preserves the same development surfaces and selectable AI tooling without
turning the workspace into a Coder Tasks template or sample application.

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
and Mux. T3 Code opens through a persistent per-workspace pairing link. The same
secret is available inside the workspace as `T3CODE_PAIRING_SECRET` and seeds T3
Code during startup. Mux provides parallel isolated agent workflows.
Interactive credentials and configuration persist on the EBS volume. Grok CLI
supports `grok login --device-auth` for remote authentication.

Optional Coder AI Gateway integration for Claude Code and Codex requires Coder
Premium and Coder 2.30 or newer.

## Architecture

The selected AWS region and subnet determine the availability zone. The
workspace creates an encrypted persistent `gp3` EBS home volume and creates an
EC2 instance only while the workspace is running. Stopping the workspace deletes
the instance and its root disk; restarting creates a fresh instance and remounts
the existing home volume. Deleting the workspace deletes the home volume.

The Coder agent authenticates with AWS instance identity. No inbound workspace
ports are required, but the instance needs outbound HTTPS access to the Coder
deployment, package registries, and selected Git hosts.

## Prerequisites

- AWS credentials available to the Coder provisioner with permissions to read
  Ubuntu AMIs and manage EC2 instances, EBS volumes, and volume attachments
- A default VPC with an available subnet, or an explicit `subnet_id` template
  variable
- Outbound network connectivity, using either a public IP or private NAT/egress
- Coder 2.24 or newer for selectable JetBrains launchers
- Wildcard workspace application access for subdomain-based apps
- Optional GitHub and GitLab external authentication providers named `github`
  and `gitlab`

If an IAM instance profile is configured, its policies become available to code
running in the workspace. Scope it according to the deployment's security model.

## Push and verify

From the repository root:

```sh
terraform -chdir=registry/coder-labs/templates/aws-ai-dev init -upgrade
terraform -chdir=registry/coder-labs/templates/aws-ai-dev validate
coder templates push aws-ai-dev -d registry/coder-labs/templates/aws-ai-dev
coder templates edit aws-ai-dev --default-ttl 2h
```

Create a default workspace, clone `https://github.com/coder/registry`, and verify
the IDEs, five AI agents, T3 Code, Mux, and Preview. Add files under
`/home/coder`, stop and restart the workspace, and confirm they persist. Finally,
create an IDE-only workspace and confirm that all optional AI resources are
absent.
