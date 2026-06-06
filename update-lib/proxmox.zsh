# proxmox.zsh
# Proxmox update functions:
#   update_proxmox

#!/bin/zsh

update_proxmox() {
cat <<'EOF'

apt-get update &&
DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade &&
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
            apt-get update &&
            DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade &&
            apt-get -y autoremove &&
            apt-get clean
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
        apt-get update &&
        DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade &&
        apt-get -y autoremove &&
        apt-get clean
    ' || echo "Guest agent missing on VM $VMID"
done

EOF
}