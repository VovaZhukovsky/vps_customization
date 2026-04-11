#!/usr/bin/env bash
# ssh.sh
# Configures sshd based on passed arguments.
#
# Usage:
#   sudo bash ssh.sh [options]
#
# Options:
#   change-port   Generate a random SSH port (1024-65535) and apply it to sshd_config

set -euo pipefail

SSHD_CONFIG="/etc/ssh/sshd_config"

log() { echo "[$(date '+%H:%M:%S')] $*" >&2; }
die() { echo "ERROR: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root (sudo)"
[[ $# -ge 1 ]]    || die "Usage: $0 <option> [option...]"

# ── Helpers ───────────────────────────────────────────────────────────────────
set_sshd_option() {
  local key="$1" value="$2"
  if grep -qE "^\s*#?\s*${key}\b" "${SSHD_CONFIG}"; then
    sed -i -E "s|^\s*#?\s*${key}\b.*|${key} ${value}|" "${SSHD_CONFIG}"
  else
    echo "${key} ${value}" >> "${SSHD_CONFIG}"
  fi
}

# ── Argument: change-port ─────────────────────────────────────────────────────
cmd_change_port() {
  # If port was already changed (not 22), skip
  local current_port
  current_port=$(grep -E "\s*Port\b" "${SSHD_CONFIG}" | awk '{print $2}' | tail -1)
  current_port="${current_port:-22}"

  if [[ "${current_port}" != "22" ]]; then
    log "SSH port already changed to ${current_port} — skipping"
    echo "${current_port}" > /tmp/ssh_new_port
    return
  fi

  # Ports to avoid: well-known services
  local avoid=(80 443 3306 5432 6379 8080 8443 9200 27017)

  local port
  while true; do
    port=$(shuf -i 1024-65535 -n 1)
    local skip=0
    for p in "${avoid[@]}"; do
      [[ "$port" -eq "$p" ]] && { skip=1; break; }
    done
    # Also skip if port is already in use
    ss -tlnp | grep -q ":${port} " && skip=1
    [[ $skip -eq 0 ]] && break
  done

  log "Setting SSH port to ${port}"
  set_sshd_option "Port" "${port}"

  log "Reloading sshd"
  systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null \
    || die "Failed to restart sshd"

  echo "${port}" > /tmp/ssh_new_port
  log "New SSH port: ${port}"
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
for arg in "$@"; do
  case "${arg}" in
    change-port) cmd_change_port ;;
    *) die "Unknown option: '${arg}'. Available: change-port" ;;
  esac
done
