#!/usr/bin/env bash
# setup_user.sh
# Creates a user, adds a public SSH key, and configures sudo access.
#
# Usage:
#   sudo bash setup_user.sh <username> <public_key>

set -euo pipefail

log() { echo "[$(date '+%H:%M:%S')] $*" >&2; }
die() { echo "ERROR: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]]  || die "Run as root (sudo)"
[[ $# -ge 2 ]]     || die "Usage: $0 <username> <public_key>"

# ── Config ───────────────────────────────────────────────────────────────────
USERNAME="$1"
PUBLIC_KEY_VALUE="$2"
USER_HOME="/home/${USERNAME}"
SSH_DIR="${USER_HOME}/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"

# ── Create user ───────────────────────────────────────────────────────────────
if id "${USERNAME}" &>/dev/null; then
  log "User '${USERNAME}' already exists — skipping creation"
else
  log "Creating user '${USERNAME}'"
  useradd \
    --create-home \
    --home-dir "${USER_HOME}" \
    --shell /bin/bash \
    --comment "Deploy user" \
    "${USERNAME}"
fi

# ── SSH directory ─────────────────────────────────────────────────────────────
log "Configuring SSH directory"
mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"
chown "${USERNAME}:${USERNAME}" "${SSH_DIR}"

# ── Authorized key ────────────────────────────────────────────────────────────
if grep -qF "${PUBLIC_KEY_VALUE}" "${AUTHORIZED_KEYS}" 2>/dev/null; then
  log "Public key already in authorized_keys — skipping"
else
  log "Adding public key to authorized_keys"
  echo "${PUBLIC_KEY_VALUE}" >> "${AUTHORIZED_KEYS}"
fi

chmod 600 "${AUTHORIZED_KEYS}"
chown "${USERNAME}:${USERNAME}" "${AUTHORIZED_KEYS}"

# ── Sudo permissions ──────────────────────────────────────────────────────────
SUDOERS_FILE="/etc/sudoers.d/${USERNAME}"
SUDOERS_RULE="${USERNAME} ALL=(ALL) NOPASSWD: ALL"

if [[ -f "${SUDOERS_FILE}" ]] && grep -qF "${SUDOERS_RULE}" "${SUDOERS_FILE}"; then
  log "Sudoers rule already present — skipping"
else
  log "Writing sudoers rule → ${SUDOERS_FILE}"
  echo "${SUDOERS_RULE}" > "${SUDOERS_FILE}"
  chmod 440 "${SUDOERS_FILE}"
  visudo -cf "${SUDOERS_FILE}" || { rm -f "${SUDOERS_FILE}"; die "sudoers syntax error — rule removed"; }
fi

log "User '${USERNAME}' ready"
echo "${USERNAME}" >&2
