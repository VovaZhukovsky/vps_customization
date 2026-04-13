# vps-customization

Scripts for configuring a fresh VPS: user setup, SSH hardening, iptables firewall, and 3x-ui proxy installation. All scripts are idempotent — safe to re-run on an already-configured server.

## Quick start

Connect as root and run:

```bash
sudo bash scripts/bootstrap.sh "<public_key>" <user1> [user2 ...]
```

`bootstrap.sh` will:
1. Create each user and add the public SSH key
2. Install [3x-ui](https://github.com/mhsanaei/3x-ui) if not already installed
3. Harden SSH and change the port to a random value (1024–65535)
4. Apply iptables firewall rules

After it finishes, the connection info is printed to stderr:

```
======== SSH access: alice ========
  ssh -p <port> -i ~/.ssh/id_rsa alice@<host>

  3x-ui tunnel:
  ssh -p <port> -N -L 2053:localhost:<xui_port> alice@<host>
  then open: http://localhost:2053
=====================================
```

## Scripts

### `bootstrap.sh`

Entry point. Creates users, installs 3x-ui, hardens SSH, applies firewall.

```
Usage: sudo bash scripts/bootstrap.sh <public_key> <user1> [user2 ...]
```

### `setup_user.sh`

Creates a user, adds a public SSH key to `authorized_keys`, grants full passwordless sudo.

```
Usage: sudo bash scripts/setup_user.sh <username> <public_key>
```

### `ssh.sh`

Modifies `/etc/ssh/sshd_config`. Accepts one or both options:

| Option        | Effect                                               |
|---------------|------------------------------------------------------|
| `change-port` | Pick a random port (1024–65535), write to `/tmp/ssh_new_port` |
| `harden`      | Disable root login and password authentication       |

```bash
sudo bash scripts/ssh.sh change-port harden
```

### `firewall.sh`

Applies iptables rules and persists them to `/etc/iptables/rules.v4`. SSH port is auto-detected from `/etc/ssh/sshd_config`.

```
Usage: sudo bash scripts/firewall.sh
```

**Rules:**

| Chain   | Policy | Allowed                                          |
|---------|--------|--------------------------------------------------|
| INPUT   | DROP   | loopback, established/related, ICMP ping (rate-limited), SSH, HTTPS (443) |
| OUTPUT  | ACCEPT | all                                              |
| FORWARD | DROP   | —                                                |

> `firewall.sh` is always run last by `bootstrap.sh` to avoid locking yourself out mid-setup.

## Requirements

- Debian/Ubuntu-based system
- Root access
- `iptables` (installed automatically if missing)
- `curl` (for 3x-ui installer)
