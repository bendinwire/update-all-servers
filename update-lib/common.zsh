# common.zsh
# Shared functions:
#   run_ssh_timed
#   check_disk_usage
#   big_warning
#   big_error
#   update_ohmyzsh_mac and update_ohmyzsh_linux live in their platform files

#!/bin/zsh

BOLD=$'\e[1m'
RESET=$'\e[0m'
GREEN=$'\e[1;32m'
YELLOW=$'\e[1;33m'

SSH_CONNECT_TIMEOUT=8
SSH_COMMAND_TIMEOUT=900
SSH_DISK_TIMEOUT=30

big_warning() {
    echo ""
    echo "############################################################"
    echo "# ⚠️ WARNING"
    echo "# $1"
    echo "############################################################"
    echo ""
}

big_error() {
    echo ""
    echo "############################################################"
    echo "# 🚨 ERROR"
    echo "# $1"
    echo "############################################################"
    echo ""
}

run_ssh_timed() {
    local timeout_secs="$1"
    local host="$2"
    local cmd="$3"

    local ssh_key="${HOME}/.ssh/id_ed25519"
    [[ ! -f "$ssh_key" ]] && ssh_key="${HOME}/.ssh/id_rsa"

    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout "${timeout_secs}s" ssh \
            -i "$ssh_key" \
            -o ConnectTimeout="$SSH_CONNECT_TIMEOUT" \
            -o BatchMode=yes \
            -o StrictHostKeyChecking=accept-new \
            -o ConnectionAttempts=1 \
            -o ServerAliveInterval=5 \
            -o ServerAliveCountMax=1 \
            ${(z)host} "$cmd"
    else
        ssh \
            -i "$ssh_key" \
            -o ConnectTimeout="$SSH_CONNECT_TIMEOUT" \
            -o BatchMode=yes \
            -o StrictHostKeyChecking=accept-new \
            -o ConnectionAttempts=1 \
            -o ServerAliveInterval=5 \
            -o ServerAliveCountMax=1 \
            ${(z)host} "$cmd"
    fi
}

check_disk_usage() {
    local host="$1"

    run_ssh_timed 30 "$host" '
        FREE_GB=$(df -k / | tail -1 | awk "{printf \"%d\", \$4/1024/1024}")
        USED_PCT=$(df -k / | tail -1 | awk "{gsub(/%/, \"\", \$5); print \$5}")
        FREE="${FREE_GB}GB"
        USED="${USED_PCT}%"

        echo ""
        if [ "$FREE_GB" -lt 2 ] || [ "$USED_PCT" -ge 95 ]; then
            echo "🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨"
            echo "# 🚨 CRITICAL STORAGE WARNING"
            echo "# 🚨 FREE: " $FREE
            echo "# 🚨 USED: " $USED
            echo "# 🚨 This server is almost out of disk space."
            echo "🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨"
        elif [ "$FREE_GB" -lt 5 ] || [ "$USED_PCT" -ge 85 ]; then
            echo "############################################################"
            echo "# ⚠️ STORAGE WARNING"
            echo "# FREE: " $FREE
            echo "# USED: " $USED
            echo "# Disk space is getting low."
            echo "############################################################"
        else
            echo "############################################################"
            echo "# 💾 STORAGE"
            echo "# FREE: " $FREE
            echo "# USED: " $USED
            echo "############################################################"
        fi

        if command -v docker >/dev/null 2>&1; then
            docker system df || true
        fi

        true
    '
}

prompt_and_run() {
    local host="$1"
    local cmd="$2"

    echo ""
    echo "============================================================"
    echo " UPDATE TARGET: $host"
    echo "============================================================"

    read "answer?Do you want to update $host? (Y/n): "
    [[ -z "$answer" ]] && answer="y"

    [[ ! "$answer" =~ '^[Yy]' ]] && return

    echo ""
    echo "🔄 Connecting to $host..."

    if run_ssh_timed "$SSH_COMMAND_TIMEOUT" "$host" "$cmd"; then
        echo "✅ Finished updating $host"
        check_disk_usage "$host" || true
    else
        big_error "Failed updating $host"
    fi
}
