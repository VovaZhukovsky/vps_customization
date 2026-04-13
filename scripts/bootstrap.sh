#!/usr/bin/env bash
# bootstrap.sh
# Creates users, adds your public SSH key, and hardens sshd.
#
# Usage:
#   sudo bash bootstrap.sh <public_key> <user1> [user2 ...]
#
# The script is idempotent: safe to re-run on an already-configured server.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Helpers ──────────────────────────────────────────────────────────────────
log() { echo "[$(date '+%H:%M:%S')] $*" >&2; }
die() { echo "ERROR: $*" >&2; exit 1; }

# ── Validation ───────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "Run as root (sudo)"
[[ $# -ge 2 ]]    || die "Usage: $0 <public_key> <user1> [user2 ...]"

PUBLIC_KEY="$1"
shift

# ── Setup users ───────────────────────────────────────────────────────────────
for user in "$@"; do
  log "Setting up user '${user}'"
  bash "${SCRIPT_DIR}/setup_user.sh" "${user}" "${PUBLIC_KEY}"
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

log "Done."

SSH_HOST=$(hostname -I | awk '{print $1}')
XUI_PORT=$(x-ui settings 2>/dev/null | grep -oP 'port: \K\d+' || echo "????")

for user in "$@"; do
  echo >&2
  echo "======== SSH access: ${user} ========" >&2
  echo "  ssh -p ${SSH_PORT} -i ~/.ssh/id_rsa ${user}@${SSH_HOST}" >&2
  echo >&2
  echo "  3x-ui tunnel:" >&2
  echo "  ssh -p ${SSH_PORT} -N -L 2053:localhost:${XUI_PORT} ${user}@${SSH_HOST}" >&2
  echo "  then open: http://localhost:2053" >&2
  echo "=====================================" >&2
done
