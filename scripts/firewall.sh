#!/usr/bin/env bash
# firewall.sh
# Applies standard iptables rules for a hardened VPS.
# SSH port is read from sshd_config automatically.
#
# Usage:
#   sudo bash firewall.sh
#
# Rules applied:
#   INPUT:   allow loopback, established/related, ICMP ping, SSH
#   OUTPUT:  allow all
#   FORWARD: drop all

set -euo pipefail

SSHD_CONFIG="/etc/ssh/sshd_config"

log() { echo "[$(date '+%H:%M:%S')] $*" >&2; }
die() { echo "ERROR: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root (sudo)"

# ── Detect SSH port ───────────────────────────────────────────────────────────
SSH_PORT=$(grep -E "^\s*Port\b" "${SSHD_CONFIG}" | awk '{print $2}' | tail -1)
SSH_PORT="${SSH_PORT:-22}"
log "SSH port: ${SSH_PORT}"

# ── Flush existing rules ──────────────────────────────────────────────────────
log "Flushing existing iptables rules"
iptables -F
iptables -X
iptables -Z

# ── Default policies ──────────────────────────────────────────────────────────
iptables -P INPUT   DROP
iptables -P FORWARD DROP
iptables -P OUTPUT  ACCEPT

# ── INPUT rules ───────────────────────────────────────────────────────────────
# Loopback
iptables -A INPUT -i lo -j ACCEPT

# Established/related connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ICMP ping (rate-limited)
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/s --limit-burst 10 -j ACCEPT

# SSH
iptables -A INPUT -p tcp --dport "${SSH_PORT}" -m conntrack --ctstate NEW -j ACCEPT

# HTTPS (Xray)
iptables -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -j ACCEPT

# ── Persist rules ─────────────────────────────────────────────────────────────
log "Saving rules"
if command -v iptables-save &>/dev/null; then
  mkdir -p /etc/iptables
  iptables-save > /etc/iptables/rules.v4
  log "Rules saved to /etc/iptables/rules.v4"
else
  log "WARNING: iptables-save not found — rules will not persist across reboots"
fi

log "Firewall configured (SSH on port ${SSH_PORT})"
