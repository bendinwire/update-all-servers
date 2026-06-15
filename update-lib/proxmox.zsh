# proxmox.zsh
# Proxmox update functions:
#   update_proxmox

#!/bin/zsh

update_proxmox() {
cat <<'EOF'
export LC_ALL=C LANGUAGE= LANG=C

apt-get update &&
apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade &&
apt-get -y autoremove &&
apt-get clean

echo ""
echo "Updating LXCs..."

for CTID in $(pct list | awk 'NR>1 {print $1}')
do
    STATUS=$(pct status $CTID | awk '{print $2}')

    if [ "$STATUS" = "running" ]; then
        echo "Updating CT $CTID"

        pct exec $CTID -- bash -c '
            export LC_ALL=C LANGUAGE= LANG=C
            apt-get update &&
            apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade &&
            apt-get -y autoremove &&
            apt-get clean

            # Pull any Docker Compose stacks running in this CT
            for DIR in $(find /opt /root /home -maxdepth 4 -name "docker-compose.yml" -o -name "compose.yml" 2>/dev/null | xargs -I{} dirname {} | sort -u); do
                echo "🐳 Pulling Docker stack in $DIR"
                cd "$DIR" && docker compose pull && docker compose up -d --remove-orphans || true
            done
        '
    fi
done

echo ""
echo "Updating VMs..."

qm list | awk 'NR>1 {print $1 "|" $2 "|" $3}' |
while IFS="|" read VMID NAME STATUS
do
    case "$NAME" in
        *homeassistant*|*haos*|*hass*)
            echo "Skipping HA VM $VMID"
            continue
        ;;
    esac

    [ "$STATUS" != "running" ] && continue

    qm guest exec "$VMID" -- bash -lc '
        export LC_ALL=C LANGUAGE= LANG=C
        apt-get update &&
        apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade &&
        apt-get -y autoremove &&
        apt-get clean
    ' || echo "Guest agent missing on VM $VMID"
done

EOF
}