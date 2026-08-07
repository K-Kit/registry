#!/usr/bin/env bash
# Cloud Agent start phase for the Coder Registry.
#
# Runs on every boot. It starts the Docker daemon that the registry's
# TypeScript module tests depend on, then returns once the daemon is ready.
# It is safe to re-run: an already-running daemon is left untouched.
set -euo pipefail

log() { echo "==> $*"; }

DOCKER_LOG="/tmp/dockerd.log"

if sudo docker info >/dev/null 2>&1; then
  log "Docker daemon already running"
else
  log "Starting Docker daemon (fuse-overlayfs, host networking)"
  # Launch detached so this script can return; logs go to $DOCKER_LOG.
  sudo bash -c "nohup dockerd >'${DOCKER_LOG}' 2>&1 &"

  log "Waiting for the Docker socket to become ready"
  for _ in $(seq 1 30); do
    if sudo docker info >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  if ! sudo docker info >/dev/null 2>&1; then
    echo "Error: Docker daemon failed to start. Last log lines:" >&2
    tail -n 20 "${DOCKER_LOG}" >&2 || true
    exit 1
  fi
fi

# Allow the workspace user to use Docker without sudo (group membership only
# takes effect in new logins, so relax the socket permissions here too).
sudo chmod 666 /var/run/docker.sock || true

log "Docker is ready: $(docker --version)"
