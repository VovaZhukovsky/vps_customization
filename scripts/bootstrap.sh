#!/usr/bin/env bash
# bootstrap.sh
# Creates deploy users, generates SSH key pairs,
# and configures sshd for GitHub Actions access.
#
# Usage:
#   sudo bash bootstrap.sh <user1> [user2 ...]
#
# After running, copy the printed secrets into GitHub → Settings → Secrets.
# The script is idempotent: safe to re-run on an already-configured server.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Helpers ──────────────────────────────────────────────────────────────────
log() { echo "[$(date '+%H:%M:%S')] $*" >&2; }
die() { echo "ERROR: $*" >&2; exit 1; }

# ── Validation ───────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "Run as root (sudo)"
[[ $# -ge 1 ]]    || die "Usage: $0 <user1> [user2 ...]"

# ── Setup users ───────────────────────────────────────────────────────────────
for user in "$@"; do
  log "Setting up user '${user}'"
  bash "${SCRIPT_DIR}/setup_user.sh" "${user}"
done

# ── Install 3x-ui ────────────────────────────────────────────────────────────
if command -v x-ui &>/dev/null || systemctl is-active --quiet x-ui 2>/dev/null; then
  log "3x-ui already installed — skipping"
else
  log "Installing 3x-ui"
  bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
fi

# ── Harden SSH + change port ─────────────────────────────────────────────────
log "Hardening SSH and changing port"
bash "${SCRIPT_DIR}/ssh.sh" harden change-port

SSH_PORT=$(cat /tmp/ssh_new_port)
rm -f /tmp/ssh_new_port

# ── Firewall ──────────────────────────────────────────────────────────────────
log "Applying firewall rules"
bash "${SCRIPT_DIR}/firewall.sh"

# ── Print GitHub Secrets ──────────────────────────────────────────────────────
log "Done."

SSH_HOST=$(hostname -I | awk '{print $1}')

for user in "$@"; do
  PRIVATE_KEY="/home/${user}/.ssh/id_ed25519"
  echo >&2
  echo "======== GitHub Actions Secrets: ${user} ========" >&2
  echo >&2
  echo "SSH_USER=${user}" >&2
  echo "SSH_HOST=${SSH_HOST}" >&2
  echo "SSH_PORT=${SSH_PORT}" >&2
  echo >&2
  echo "SSH_KEY:" >&2
  cat "${PRIVATE_KEY}"
  echo >&2
  echo "=================================================" >&2
done
