#!/bin/zsh

set -e

# Ensure full PATH for cron environments
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export HOME="${HOME:-/Users/tornado}"

SCRIPT_DIR="${0:A:h}"
LIB_DIR="$SCRIPT_DIR/update-lib"

if [[ ! -f "$SCRIPT_DIR/config.zsh" ]]; then
  echo "❌ Missing config.zsh — copy config.zsh.example and fill in your values."
  exit 1
fi

source "$SCRIPT_DIR/config.zsh"
source "$LIB_DIR/common.zsh"
source "$LIB_DIR/mac.zsh"
source "$LIB_DIR/linux.zsh"
source "$LIB_DIR/docker.zsh"
source "$LIB_DIR/proxmox.zsh"

UPDATE_ALL=false
[[ "$1" == "--all" || "$1" == "-y" || "$1" == "--yes" ]] && UPDATE_ALL=true

LOG_FILE="$HOME/logs/update_all_servers.log"
RUN_LOG=$(mktemp -t update-run)

# Capture all output to RUN_LOG while still printing to terminal
exec > >(tee "$RUN_LOG") 2>&1

typeset -A HOSTS
typeset -A COMMANDS

HOSTS=(
  "Mac Mini"       "$HOST_MACMINI"
  "JF Mac Mini"    "$HOST_JFMACMINI"
  "MBP"            "$HOST_MBP"
  "MBA13"          "$HOST_MBA13"
  "MBA15"          "$HOST_MBA15"
  "Elsa MBA"       "$HOST_ELSAMBA"
  "iMac Pro"       "$HOST_IMACPRO"

  "Local Proxmox"  "$HOST_PROXMOX"

  "TLB Docker"     "$HOST_TLB"
  "Beelink Plex"   "$HOST_BEELINK"

  "QTPi"           "$HOST_QTPI"
  "PoolPi"         "$HOST_POOLPI"
  "ChickenPi"      "$HOST_CHICKENPI"
  "GatePi"         "$HOST_GATEPI"
)

COMMANDS=(
  "Mac Mini"       "$(update_mac)"
  "JF Mac Mini"    "$(update_mac)"
  "MBP"            "$(update_mac)"
  "MBA13"          "$(update_mac)"
  "MBA15"          "$(update_mac)"
  "Elsa MBA"       "$(update_mac)"
  "iMac Pro"       "$(update_mac)"

  "Local Proxmox"  "$(update_proxmox)"

  "TLB Docker"     "$(update_linux)
$(update_docker_host)
$(update_ohmyzsh_linux)"

  "Beelink Plex"   "$(update_linux)
$(update_docker_host)
$(update_ohmyzsh_linux)"

  "QTPi"           "$(update_linux)
$(update_ohmyzsh_linux)"

  "PoolPi"         "$(update_linux)
$(update_ohmyzsh_linux)"

  "ChickenPi"      "$(update_linux)
$(update_ohmyzsh_linux)
$(restart_pm2_all "ChickenPi")"

  "GatePi"         "$(update_linux)
$(update_ohmyzsh_linux)
$(restart_pm2_all "GatePi")"
)

ORDER=(
  "Mac Mini"
  "JF Mac Mini"
  "MBP"
  "MBA13"
  "MBA15"
  "Elsa MBA"
  "iMac Pro"
  "Local Proxmox"
  "TLB Docker"
  "Beelink Plex"
  "QTPi"
  "PoolPi"
  "ChickenPi"
  "GatePi"
)

typeset -a ISSUE_SUMMARY

for name in "${ORDER[@]}"; do
  host="${HOSTS[$name]}"
  cmd="${COMMANDS[$name]}"

  if $UPDATE_ALL; then
    echo ""
    echo "============================================================"
    echo " AUTO UPDATING: $name"
    echo "============================================================"
  else
    echo ""
    echo $'\e[1;44;97m============================================================\e[0m'
    echo $'\e[1;44;97m UPDATE TARGET: '"$name"$' \e[0m'
    echo $'\e[1;44;97m============================================================\e[0m'

    read "answer?Do you want to update $name? (Y/n): "
    [[ -z "$answer" ]] && answer="y"

    if [[ ! "$answer" =~ '^[Yy]' ]]; then
      echo "⏭️  Skipped $name."
      ISSUE_SUMMARY+=("⏭️  $name — skipped")
      continue
    fi
  fi

  echo ""
  echo "🔄 Connecting to $host..."

  TMPLOG=$(mktemp -t update-host)

  run_ssh_timed "$SSH_COMMAND_TIMEOUT" "$host" "$cmd" 2>&1 | tee "$TMPLOG"
  ssh_ok=${pipestatus[1]}

  if [[ $ssh_ok -eq 0 ]]; then
    echo "✅ Finished updating $name"
    check_disk_usage "$host" 2>&1 | tee -a "$TMPLOG"
  else
    big_error "Failed updating $name ($host)"
    ISSUE_SUMMARY+=("🚨  $name — connection failed or timed out")
  fi

  # Collect notable lines for summary
  local host_issues=()
  local in_storage_warn=false
  while IFS= read -r line; do
    if [[ "$line" =~ (STORAGE WARNING|CRITICAL STORAGE) ]]; then
      in_storage_warn=true
      host_issues+=("      $line")
    elif $in_storage_warn && [[ "$line" =~ (FREE:|USED:) ]]; then
      host_issues+=("      $line")
    elif [[ "$line" =~ '#{10,}' ]]; then
      in_storage_warn=false
    elif [[ "$line" =~ (⚠️|🚨|\ failed|Failed|Command Line Tools) ]]; then
      host_issues+=("      $line")
    fi
  done < "$TMPLOG"
  rm -f "$TMPLOG"

  if [[ ${#host_issues[@]} -gt 0 ]]; then
    ISSUE_SUMMARY+=("⚠️  $name:")
    ISSUE_SUMMARY+=("${host_issues[@]}")
  fi
done

echo
echo "🎉 All updates complete."

# Build summary block
SUMMARY_LINES=()
SUMMARY_LINES+=("============================================================")
SUMMARY_LINES+=(" 🗓  $(date '+%A %b %d %Y at %I:%M %p')")
SUMMARY_LINES+=("============================================================")
SUMMARY_LINES+=(" 📋 SUMMARY")
SUMMARY_LINES+=("============================================================")
if [[ ${#ISSUE_SUMMARY[@]} -eq 0 ]]; then
  SUMMARY_LINES+=(" ✅ All hosts updated cleanly.")
else
  for line in "${ISSUE_SUMMARY[@]}"; do
    SUMMARY_LINES+=("$line")
  done
fi
SUMMARY_LINES+=("============================================================")

# Print summary to terminal
echo ""
for line in "${SUMMARY_LINES[@]}"; do echo "$line"; done

# Write to log file: summary first, then full run output
mkdir -p "$HOME/logs"
ENTRY=$(mktemp -t update-entry)
{
  for line in "${SUMMARY_LINES[@]}"; do echo "$line"; done
  echo ""
  echo "--- FULL OUTPUT ---"
  echo ""
  cat "$RUN_LOG"
  echo ""
} > "$ENTRY"

# Prepend this run's entry to the top of the log file
if [[ -f "$LOG_FILE" ]]; then
  cat "$ENTRY" "$LOG_FILE" > /tmp/update-combined.log
  mv /tmp/update-combined.log "$LOG_FILE"
else
  mv "$ENTRY" "$LOG_FILE"
fi
rm -f "$ENTRY" "$RUN_LOG"

# Send email on --all runs
if $UPDATE_ALL; then
  SUMMARY_TEXT="${(j:\n:)SUMMARY_LINES}"

  {
    echo "Subject: 🖥️ Weekly Update Report — $(date '+%A %b %d')"
    echo "To: $EMAIL_TO"
    echo "From: $EMAIL_FROM"
    echo "Content-Type: text/plain; charset=UTF-8"
    echo ""
    echo "$SUMMARY_TEXT"
    echo ""
    echo "FULL LOG"
    echo "========"
    head -500 "$LOG_FILE"
  } | /opt/homebrew/bin/msmtp "$EMAIL_TO" 2>&1 && echo "📧 Summary emailed." || echo "⚠️  Email failed."
fi
