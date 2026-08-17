# ~/bin — Claude working notes

This dir is a git repo (`github.com:bendinwire/update-all-servers`) **and** a
Syncthing folder, so committed changes propagate to the fleet. It's also a
grab-bag of many unrelated personal scripts — the guidance below is about the
**fleet update system**, which is the main thing worth working on here.

## Fleet updater — the important thing in this repo
Entry point: `update_all_servers.zsh` · per-OS modules: `update-lib/{common,mac,
linux,docker,proxmox}.zsh` · hosts/email config: `config.zsh` (from
`config.zsh.example`).

It SSHes into every homelab host (Macs, Linux, Docker, Proxmox, Pis), runs
per-OS update routines, prints/writes a summary, and emails it on `--all` runs.

Cron (Mon/Thu 03:00 + weekdays 12:00) runs `~/bin/update_all_servers.zsh --all`.
Logs: `~/logs/update_all_servers.log` (newest run prepended).

Full write-up (schedule, behavior, gotchas, host list):
`~/Developer/homelab/FLEET_UPDATER.md` — read it first.

## Rules for editing these scripts
- **Edit here (`~/bin`), never `~/Documents/scripts/`** (aka `~/Scripts` /
  `~/scripts`). That's a stale, divergent copy that cron does NOT run.
- **Macs are list-only.** `update-lib/mac.zsh` runs `softwareupdate -l` — it
  reports OS/CLT updates, it does **not** install them (`softwareupdate -ia` is
  intentionally not enabled). Don't add auto-install without asking.
- **Beta updates are filtered out** of the softwareupdate report (see
  `update_mac`). Keep them excluded unless asked otherwise.
- The per-host **summary flags any output line** matching
  `⚠️|🚨|failed|Failed|Command Line Tools` (in `update_all_servers.zsh`). Don't
  emit those substrings in status lines unless you want them flagged.
- **Test module output before committing.** The `update_*` functions emit a
  script *string* (heredoc) that's sent over SSH — mind heredoc escaping
  (`\$`, `\*`). Exercise the logic with sample data locally first.

## Environment gotchas
- **Run from Terminal.app, not the Claude desktop app**, for anything that
  SSHes into a fleet host. The embedded desktop CLI can't reach the LAN
  (`EHOSTUNREACH`); Terminal.app has the permanent Local Network grant. Editing
  scripts is fine anywhere; *running* them against real hosts needs Terminal.
- **No passwordless sudo on the fleet** — anything needing root (e.g.
  `softwareupdate --clear-catalog`) must be run by the user by hand.
- `chmod` is blocked in this harness; set exec bits with
  `git update-index --chmod=+x`.

## Landing changes
Per the user's policy: after editing, commit and push (this repo's default
branch is `main`, remote `origin`). Stage only the files you changed — never
touch the many unrelated unstaged scripts in this dir.
