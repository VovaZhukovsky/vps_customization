# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

VPS server customization automation. Scripts for configuring a fresh VPS: iptables firewall rules, SSH hardening, and Xray proxy setup. GitHub Actions connects via SSH and runs scripts on the target server.

## Structure

```
scripts/
  setup_github_runner_user.sh  # bootstrap CI access: create user + generate SSH key pair
  firewall.sh                  # iptables rules (INPUT/OUTPUT/FORWARD chains)
  ssh.sh                       # harden sshd_config
  xray.sh                      # install and configure Xray-core
.github/
  workflows/
    check-ssh.yml              # manual workflow to verify SSH connectivity
    deploy.yml                 # run deploy scripts on VPS (planned)
```

## Design Conventions

- All scripts are idempotent — safe to re-run on an already-configured server.
- Each script uses `set -euo pipefail` — exits on first error.
- Secrets (SSH private key, VPS IP, Xray UUID) live in GitHub Actions secrets only.
- `firewall.sh` always runs last to avoid locking out the CI runner mid-deploy.
- Xray config: `/usr/local/etc/xray/config.json`.
- iptables rules persist via `iptables-save > /etc/iptables/rules.v4` (requires `iptables-persistent` on Ubuntu/Debian).

## Bootstrapping a New Server

Run once manually on the VPS to create the `github-runner` user and generate an SSH key pair:

```bash
sudo bash scripts/setup_github_runner_user.sh
```

The script prints all four GitHub Secrets at the end: `SSH_KEY` (private key), `SSH_HOST`, `SSH_PORT`, `SSH_USER`.

The `github-runner` user gets passwordless sudo only for `/opt/deploy/*.sh`.

## GitHub Actions Pattern

Uses `webfactory/ssh-agent` with the private key from `SSH_KEY` secret:

```yaml
- uses: webfactory/ssh-agent@v0.9.0
  with:
    ssh-private-key: ${{ secrets.SSH_KEY }}
- run: ssh-keyscan -p ${{ secrets.SSH_PORT }} ${{ secrets.SSH_HOST }} >> ~/.ssh/known_hosts
- run: ssh -p ${{ secrets.SSH_PORT }} ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }} "..."
```
