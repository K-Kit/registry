---
display_name: GCP Loaded Container
description: Run a loaded Coder workspace in a privileged container on Google Compute Engine
icon: ../.icons/gcp.svg
verified: false
tags: [gcp, docker, container, ai, ide]
---

# GCP Loaded Container

Provision a Google Compute Engine VM that runs the Coder workspace inside a privileged OCI container. The container includes code-server, Claude Code, Codex, JupyterLab, File Browser, Git configuration, dotfiles, and personalization modules.

## Prerequisites

The Coder provisioner requires Google Cloud credentials with permission to create Compute Engine instances, disks, networks, and service-account attachments. Set `project_id` to the target Google Cloud project.

The selected container image must be Debian or Ubuntu based, provide Bash and passwordless `sudo`, and support `amd64`. The default Coder enterprise base image meets these requirements.

## Architecture

Each running workspace creates one Compute Engine VM using Google's container-optimized host image. The VM launches a privileged workspace container with host networking. Shared runtime prerequisites—including `uv`, Python, Zsh, unzip, and native build tools—are installed inside the container before the Coder agent starts, preventing module installer races.

The VM boot disk and workspace container are deleted when the workspace stops. Use the existing `gcp-loaded` template when persistent VM storage is required.

> [!IMPORTANT]
> Changing the container image can break bootstrap or module installation if the image is not Debian or Ubuntu based or does not include passwordless `sudo`.
