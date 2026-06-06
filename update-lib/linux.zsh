#!/bin/zsh

update_linux() {
cat <<'EOF'
export LC_ALL=C LANGUAGE= LANG=C
sudo apt-get update &&
sudo DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade &&
sudo apt-get -y autoremove &&
sudo apt-get clean

if [ -d "$HOME/.oh-my-zsh" ]; then
    export DISABLE_UPDATE_PROMPT=true
    "$HOME/.oh-my-zsh/tools/upgrade.sh"
fi
EOF
}

restart_pm2_all() {
cat <<'EOF'
if command -v pm2 >/dev/null 2>&1; then
    pm2 restart all --update-env || true
    pm2 save || true
fi
EOF
}

update_ohmyzsh_linux() {
cat <<'EOF'
if [ -d "$HOME/.oh-my-zsh" ]; then
  echo ""
  echo "Updating Oh My Zsh..."
  export DISABLE_UPDATE_PROMPT=true
  "$HOME/.oh-my-zsh/tools/upgrade.sh" >/tmp/omz-update.log 2>&1 || {
    echo "############################################################"
    echo "# ⚠️ OH MY ZSH WARNING"
    echo "# Oh My Zsh update failed. See /tmp/omz-update.log"
    echo "############################################################"
  }
fi
EOF
}

warn_skip_os() {
  local name="$1"

cat <<EOF
echo ""
echo "############################################################"
echo "# ⚠️ ATTENTION REQUIRED"
echo "# Skipping $name OS packages because sudo requires a password."
echo "############################################################"
EOF
}
