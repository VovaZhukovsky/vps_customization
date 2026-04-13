# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

VPS server customization automation. Scripts for configuring a fresh VPS: iptables firewall rules, SSH hardening, and Xray proxy setup. Run manually on the server as root.

## Structure

```
scripts/
  bootstrap.sh    # entry point: creates users, changes SSH port, prints connection info
  setup_user.sh   # creates a user, generates ed25519 SSH key pair, configures sudoers
  ssh.sh          # hardens sshd_config (options: change-port, harden)
  firewall.sh     # iptables rules (INPUT/OUTPUT/FORWARD chains), reads SSH port from sshd_config
```

## Design Conventions

- All scripts are idempotent — safe to re-run on an already-configured server.
- Each script uses `set -euo pipefail` — exits on first error.
- `firewall.sh` always runs last to avoid locking yourself out mid-setup.
- `firewall.sh` auto-detects SSH port from `/etc/ssh/sshd_config`.
- iptables rules persist via `iptables-save > /etc/iptables/rules.v4`.

## Bootstrapping a New Server

Connect as root, then run:

```bash
sudo bash scripts/bootstrap.sh <username> [username2 ...]
```

`bootstrap.sh` calls `setup_user.sh` for each user, runs `ssh.sh harden change-port`, then prints the private key and connection instructions for each user.

Copy the printed private key to `~/.ssh/id_ed25519` on your local machine, then connect:

```bash
ssh -p <port> -i ~/.ssh/id_ed25519 <username>@<host>
```

Each user gets full passwordless sudo (`NOPASSWD: ALL`).

## ssh.sh Options

```bash
sudo bash scripts/ssh.sh change-port   # pick random port (1024-65535), write to /tmp/ssh_new_port
sudo bash scripts/ssh.sh harden        # disable root login and password auth
sudo bash scripts/ssh.sh change-port harden  # both at once
```
