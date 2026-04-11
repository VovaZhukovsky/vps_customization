# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

VPS server customization automation. Scripts for configuring a fresh VPS: iptables firewall rules, SSH hardening, and Xray proxy setup. GitHub Actions connects via SSH and runs scripts on the target server.

## Structure

```
scripts/
  bootstrap.sh    # entry point: creates deploy users, changes SSH port, prints GitHub Secrets
  setup_user.sh   # creates a user, generates ed25519 SSH key pair, configures sudoers
  ssh.sh          # hardens sshd_config (options: change-port, harden)
  firewall.sh     # iptables rules (INPUT/OUTPUT/FORWARD chains), reads SSH port from sshd_config
.github/
  workflows/
    check-ssh.yml # manual workflow to verify SSH connectivity
```

## Design Conventions

- All scripts are idempotent — safe to re-run on an already-configured server.
- Each script uses `set -euo pipefail` — exits on first error.
- Secrets (SSH private key, VPS IP) live in GitHub Actions secrets only.
- `firewall.sh` always runs last to avoid locking out the CI runner mid-deploy.
- `firewall.sh` auto-detects SSH port from `/etc/ssh/sshd_config`.
- iptables rules persist via `iptables-save > /etc/iptables/rules.v4`.

## Bootstrapping a New Server

Run once manually on the VPS:

```bash
sudo bash scripts/bootstrap.sh <username> [username2 ...]
```

`bootstrap.sh` calls `setup_user.sh` for each user, runs `ssh.sh change-port`, then prints GitHub Secrets (`SSH_KEY`, `SSH_HOST`, `SSH_PORT`, `SSH_USER`) for each user.

Each deploy user gets passwordless sudo only for `/opt/deploy/*.sh`.

## ssh.sh Options

```bash
sudo bash scripts/ssh.sh change-port   # pick random port (1024-65535), write to /tmp/ssh_new_port
sudo bash scripts/ssh.sh harden        # disable root login and password auth
sudo bash scripts/ssh.sh change-port harden  # both at once
```

## GitHub Actions Pattern

Uses `webfactory/ssh-agent` with the private key from `SSH_KEY` secret:

```yaml
- uses: webfactory/ssh-agent@v0.9.0
  with:
    ssh-private-key: ${{ secrets.SSH_KEY }}
- run: ssh-keyscan -p ${{ secrets.SSH_PORT }} ${{ secrets.SSH_HOST }} >> ~/.ssh/known_hosts
- run: ssh -p ${{ secrets.SSH_PORT }} ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }} "..."
```
