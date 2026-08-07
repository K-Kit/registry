#!/usr/bin/env bash
# Cloud Agent install phase for the Coder Registry.
#
# Runs once after the repository is checked out (and again when the environment
# is rebuilt). It installs the toolchain the registry's canonical commands need
# -- Terraform, Bun, and Docker -- and then bootstraps repository dependencies.
# Per-boot work (starting the Docker daemon) lives in start.sh instead.
#
# The script is idempotent: every install step is guarded so re-running it on a
# cached or snapshotted VM is fast and safe.
set -euo pipefail

# Pinned to the latest stable Terraform release. Bump deliberately.
TERRAFORM_VERSION="1.15.8"

log() { echo "==> $*"; }

install_terraform() {
  if command -v terraform >/dev/null 2>&1; then
    log "Terraform already installed: $(terraform version | head -n1)"
    return
  fi
  log "Installing Terraform ${TERRAFORM_VERSION}"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL -o "${tmp}/terraform.zip" \
    "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
  unzip -o "${tmp}/terraform.zip" -d "${tmp}" >/dev/null
  sudo mv "${tmp}/terraform" /usr/local/bin/terraform
  rm -rf "${tmp}"
  terraform version | head -n1
}

install_bun() {
  if [[ ! -x "${HOME}/.bun/bin/bun" ]]; then
    log "Installing Bun"
    curl -fsSL https://bun.sh/install | bash
  else
    log "Bun already installed"
  fi
  # Expose bun on the system PATH so non-login shells (and this script) find it.
  sudo ln -sf "${HOME}/.bun/bin/bun" /usr/local/bin/bun
  export PATH="${HOME}/.bun/bin:${PATH}"
  bun --version
}

install_docker() {
  # The registry's TypeScript module tests (`bun run tstest`) spin up Docker
  # containers with `--network host`, so a working Docker engine is required.
  if ! command -v dockerd >/dev/null 2>&1; then
    log "Installing Docker and rootless-friendly storage/networking helpers"
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
      docker.io fuse-overlayfs iptables uidmap
  else
    log "Docker already installed: $(docker --version)"
  fi

  # fuse-overlayfs works inside the nested Cloud Agent VM where the default
  # overlay2 driver cannot mount. Bridge networking and iptables are disabled
  # because the tests only use host networking.
  log "Writing /etc/docker/daemon.json"
  sudo mkdir -p /etc/docker
  echo '{"storage-driver":"fuse-overlayfs","iptables":false,"bridge":"none"}' \
    | sudo tee /etc/docker/daemon.json >/dev/null

  # Let the workspace user talk to the daemon socket without sudo.
  sudo groupadd -f docker
  sudo usermod -aG docker "$(id -un)"
}

bootstrap_repo() {
  log "Installing JavaScript dependencies (bun install)"
  bun install --frozen-lockfile

  if command -v go >/dev/null 2>&1; then
    log "Pre-fetching Go modules for README validation"
    go mod download || echo "Warning: 'go mod download' failed; readmevalidation will fetch on demand"
  else
    echo "Warning: Go not found on PATH; skipping module pre-fetch"
  fi
}

install_terraform
install_bun
install_docker
bootstrap_repo

log "Install phase complete"
