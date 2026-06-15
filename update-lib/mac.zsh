# mac.zsh
# Mac update functions:
#   update_mac
#   update_ohmyzsh_mac

#!/bin/zsh

update_ohmyzsh_mac() {
cat <<'EOF'
if [ -d "$HOME/.oh-my-zsh/.git" ]; then
  echo ""
  echo "Updating Oh My Zsh..."

  cd "$HOME/.oh-my-zsh" || exit 0

  if git status --porcelain | grep -Eqv '^(\?\?| D)'; then
    echo "⚠️ Oh My Zsh has local changes; skipping update."
  else
    export DISABLE_UPDATE_PROMPT=true
    "$HOME/.oh-my-zsh/tools/upgrade.sh" >/tmp/omz-update.log 2>&1 || {
      echo "############################################################"
      echo "# ⚠️ OH MY ZSH WARNING"
      echo "# Oh My Zsh update failed. See /tmp/omz-update.log"
      echo "############################################################"
    }
  fi
fi
EOF
}

update_mac() {
cat <<EOF

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:\$PATH"

echo ""
echo "🍺 Updating Homebrew..."
if command -v brew >/dev/null 2>&1; then
  brew update &&
  brew upgrade &&
  echo "" &&
  echo "📦 Updating Homebrew casks..." &&
  brew outdated --cask -q >/tmp/brew-outdated-casks.log 2>&1 &&
  if [ -s /tmp/brew-outdated-casks.log ]; then
    cat /tmp/brew-outdated-casks.log
    brew upgrade --cask
  else
    echo "No outdated casks."
  fi &&
  brew autoremove &&
  brew cleanup
else
  echo "⚠️ brew not found"
fi

$(update_ohmyzsh_mac)

echo ""
echo "🖥️ Checking macOS/CLT updates..."
updates=\$(softwareupdate -l 2>/dev/null)
if echo "\$updates" | grep -q "No new software available"; then
  echo "No new software available."
else
  echo "\$updates"
fi

EOF
}
