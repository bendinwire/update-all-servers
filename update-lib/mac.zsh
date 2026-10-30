# mac.zsh
# Mac update functions:
#   update_mac
#   update_ohmyzsh_mac
#   update_iterm_mac
#   update_mas_mac

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

update_iterm_mac() {
cat <<'EOF'
# iTerm2's cask is auto_updates, so the plain `brew upgrade --cask` above skips
# it. Check it on its own against brew's latest, whether brew installed it or
# iTerm2's own Sparkle updater did. A copy brew doesn't manage is taken over
# with --force so later runs keep it current. An open iTerm2 is left alone:
# swapping the bundle under a live process can crash it.
ITERM_APP="/Applications/iTerm.app"
if [ -d "$ITERM_APP" ] && command -v brew >/dev/null 2>&1; then
  echo ""
  echo "🖥️ Checking iTerm2..."
  iterm_have=$(defaults read "$ITERM_APP/Contents/Info" CFBundleShortVersionString 2>/dev/null)
  iterm_latest=$(brew info --cask iterm2 2>/dev/null | awk 'NR==1 { print $3 }')
  if [ -z "$iterm_have" ] || [ -z "$iterm_latest" ]; then
    echo "⚠️ Couldn't read iTerm2 versions (installed: ${iterm_have:-?}, latest: ${iterm_latest:-?})"
  elif [ "$(printf '%s\n%s\n' "$iterm_have" "$iterm_latest" | sort -V | tail -1)" = "$iterm_have" ]; then
    echo "iTerm2 $iterm_have is up to date."
  elif pgrep -xq iTerm2; then
    echo "ℹ️  iTerm2 $iterm_have -> $iterm_latest available; it's open, so a later run will install it once it's quit."
  elif brew list --cask iterm2 >/dev/null 2>&1; then
    echo "Upgrading iTerm2 $iterm_have -> $iterm_latest..."
    brew upgrade --cask --greedy iterm2 || echo "⚠️ iTerm2 upgrade failed"
  else
    echo "Installing iTerm2 $iterm_latest over the non-brew $iterm_have (brew manages it from now on)..."
    brew install --cask --force iterm2 || echo "⚠️ iTerm2 install failed"
  fi
fi
EOF
}

update_mas_mac() {
cat <<'EOF'
# Mac App Store apps, via mas (installed from brew on first run). Listing is
# unprivileged, but since mas 4.0 installing needs root (an installd change in
# macOS 26.1 / 15.7.2 / 14.8.2), and the fleet has no passwordless sudo. So it
# upgrades only where sudoers lets this user run mas with no password, and
# otherwise just reports what's waiting. Needs the App Store signed in.
if command -v brew >/dev/null 2>&1; then
  echo ""
  echo "🛍️ Checking App Store apps..."
  if ! command -v mas >/dev/null 2>&1; then
    echo "Installing mas..."
    brew install mas >/tmp/mas-install.log 2>&1 || echo "⚠️ mas install failed. See /tmp/mas-install.log"
  fi
  if command -v mas >/dev/null 2>&1; then
    mas outdated >/tmp/mas-outdated.log 2>&1
    mas_rc=$?
    mas_n=$(grep -cE '^ *[0-9]+ ' /tmp/mas-outdated.log)
    if [ "$mas_rc" -ne 0 ]; then
      echo "⚠️ mas outdated failed:"
      cat /tmp/mas-outdated.log
    elif [ "$mas_n" -eq 0 ]; then
      echo "No App Store updates."
    else
      cat /tmp/mas-outdated.log
      mas_bin=$(command -v mas)
      if sudo -n -l "$mas_bin" upgrade >/dev/null 2>&1; then
        sudo -n "$mas_bin" upgrade || echo "⚠️ mas upgrade failed"
      else
        echo "ℹ️  $mas_n App Store update(s) waiting; installing needs passwordless sudo for $mas_bin (see FLEET_UPDATER.md)."
      fi
    fi
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

$(update_iterm_mac)

$(update_mas_mac)

$(update_ohmyzsh_mac)

echo ""
echo "🖥️ Checking macOS/CLT updates (betas excluded)..."
raw=\$(softwareupdate -l 2>/dev/null)
# Drop beta items so they are never surfaced, flagged, or (if install is ever
# enabled) installed. Each softwareupdate item is a "* Label:" line followed by
# an indented "Title:" line; skip the pair when either mentions "beta".
filtered=\$(echo "\$raw" | awk '
  /^\* Label:/ { lbl=\$0; getline ttl; if (tolower(lbl ttl) ~ /beta/) next; print lbl; print ttl; next }
  { print }
')
if echo "\$raw" | grep -q "No new software available"; then
  echo "No new software available."
elif echo "\$filtered" | grep -q "^\* Label:"; then
  echo "\$filtered"
else
  echo "No new (non-beta) software available."
fi
nbeta=\$(echo "\$raw" | grep -icE 'Label:.*beta')
if [ "\$nbeta" -gt 0 ]; then
  echo "ℹ️  \$nbeta beta update(s) skipped (not installed, not reported)."
fi

EOF
}
