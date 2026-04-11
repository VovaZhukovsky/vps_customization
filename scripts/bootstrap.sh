#!/usr/bin/env bash
# bootstrap.sh
# Creates a dedicated 'github-runner' user, generates an SSH key pair,
# and configures sshd for GitHub Actions access.
#
# Usage:
#   sudo bash bootstrap.sh
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

# ── Config ───────────────────────────────────────────────────────────────────
RUNNER_USER="github-runner"
RUNNER_HOME="/home/${RUNNER_USER}"
SSH_DIR="${RUNNER_HOME}/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"
PRIVATE_KEY="${SSH_DIR}/id_ed25519"
PUBLIC_KEY="${SSH_DIR}/id_ed25519.pub"

# ── Create user ───────────────────────────────────────────────────────────────
if id "${RUNNER_USER}" &>/dev/null; then
  log "User '${RUNNER_USER}' already exists — skipping creation"
else
  log "Creating user '${RUNNER_USER}'"
  useradd \
    --create-home \
    --home-dir "${RUNNER_HOME}" \
    --shell /bin/bash \
    --comment "GitHub Actions deploy user" \
    "${RUNNER_USER}"
fi

# ── SSH directory ─────────────────────────────────────────────────────────────
log "Configuring SSH directory"
mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"
chown "${RUNNER_USER}:${RUNNER_USER}" "${SSH_DIR}"

# ── Generate key pair ─────────────────────────────────────────────────────────
if [[ -f "${PRIVATE_KEY}" ]]; then
  log "SSH key already exists — skipping generation"
else
  log "Generating ed25519 key pair"
  ssh-keygen -t ed25519 -N "" -C "github-actions" -f "${PRIVATE_KEY}"
  chown "${RUNNER_USER}:${RUNNER_USER}" "${PRIVATE_KEY}" "${PUBLIC_KEY}"
  chmod 600 "${PRIVATE_KEY}"
  chmod 644 "${PUBLIC_KEY}"
fi

# ── Authorized key ────────────────────────────────────────────────────────────
if grep -qF "$(cat "${PUBLIC_KEY}")" "${AUTHORIZED_KEYS}" 2>/dev/null; then
  log "Public key already in authorized_keys — skipping"
else
  log "Adding public key to authorized_keys"
  cat "${PUBLIC_KEY}" >> "${AUTHORIZED_KEYS}"
fi

chmod 600 "${AUTHORIZED_KEYS}"
chown "${RUNNER_USER}:${RUNNER_USER}" "${AUTHORIZED_KEYS}"

# ── Sudo permissions ──────────────────────────────────────────────────────────
SUDOERS_FILE="/etc/sudoers.d/github-runner"
SUDOERS_RULE="${RUNNER_USER} ALL=(ALL) NOPASSWD: /opt/deploy/*.sh"

if [[ -f "${SUDOERS_FILE}" ]] && grep -qF "${SUDOERS_RULE}" "${SUDOERS_FILE}"; then
  log "Sudoers rule already present — skipping"
else
  log "Writing sudoers rule → ${SUDOERS_FILE}"
  echo "${SUDOERS_RULE}" > "${SUDOERS_FILE}"
  chmod 440 "${SUDOERS_FILE}"
  visudo -cf "${SUDOERS_FILE}" || { rm -f "${SUDOERS_FILE}"; die "sudoers syntax error — rule removed"; }
fi

# ── Change SSH port ───────────────────────────────────────────────────────────
log "Changing SSH port"
bash "${SCRIPT_DIR}/ssh.sh" change-port

SSH_PORT=$(cat /tmp/ssh_new_port)
rm -f /tmp/ssh_new_port

# ── Print GitHub Secrets ──────────────────────────────────────────────────────
log "Done."

SSH_HOST=$(hostname -I | awk '{print $1}')

echo >&2
echo "======== GitHub Actions Secrets ========" >&2
echo >&2
echo "SSH_USER=${RUNNER_USER}" >&2
echo "SSH_HOST=${SSH_HOST}" >&2
echo "SSH_PORT=${SSH_PORT}" >&2
echo >&2
echo "SSH_KEY:" >&2
cat "${PRIVATE_KEY}"
echo >&2
echo "========================================" >&2
