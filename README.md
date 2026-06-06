# update-all-servers

A collection of zsh scripts that remotely update a fleet of Macs, Linux servers, Raspberry Pis, and Docker hosts over SSH.

## Features

- Updates Homebrew and Oh My Zsh on macOS hosts
- Runs `apt-get dist-upgrade` on Linux/Raspberry Pi hosts
- Pulls and restarts Docker Compose stacks
- Updates Proxmox VE hosts and all running LXC containers and VMs
- Checks disk usage on every host and warns on low free space
- Collects warnings/errors into a summary at the top of the log
- Emails the summary on unattended (`--all`) runs via msmtp
- Prepends each run's entry to `~/logs/update_all_servers.log`

## Requirements

- macOS (with zsh, Homebrew, msmtp)
- SSH key-based auth to all hosts (no password prompts)
- `gtimeout` from GNU coreutils for per-host timeouts: `brew install coreutils`
- `msmtp` configured for SMTP (email): `brew install msmtp`

## Setup

1. Copy the example config and fill in your values:

   ```zsh
   cp ~/bin/config.zsh.example ~/bin/config.zsh
   $EDITOR ~/bin/config.zsh
   ```

2. Ensure `~/bin` is in your `$PATH`.

3. Run interactively (prompts before each host):

   ```zsh
   update_all_servers.zsh
   ```

4. Run unattended (updates all hosts, emails summary):

   ```zsh
   update_all_servers.zsh --all
   ```

## Cron / launchd

Add to crontab (replace path as needed):

```
0 8 * * 1,4 /Users/you/bin/update_all_servers.zsh --all
```

## File layout

```
~/bin/
├── update_all_servers.zsh   # Main orchestration script
├── config.zsh               # Private config (gitignored)
├── config.zsh.example       # Template — commit this, not config.zsh
└── update-lib/
    ├── common.zsh            # SSH runner, disk check, shared helpers
    ├── mac.zsh               # macOS update (Homebrew, softwareupdate, OMZ)
    ├── linux.zsh             # Linux update (apt, OMZ, pm2)
    ├── docker.zsh            # Docker Compose pull + restart
    └── proxmox.zsh           # Proxmox VE + LXC/VM updates
```

## Sensitive info

Everything host-specific (IP addresses, usernames, email addresses, Docker paths) lives in `config.zsh`, which is gitignored. See `config.zsh.example` for the full list of required variables.
