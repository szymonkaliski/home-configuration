#!/usr/bin/env bash

# everything that needs the shell environment home-manager links to already exist

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

DOTFILE_DIR="$(pwd)/dotfiles"

HOST="${1:-}"

case "$HOST" in
  orchid | minix | berry) ;;
  *)
    echo "Usage: ${BASH_SOURCE[0]##*/} <orchid|minix|berry>"
    exit 1
    ;;
esac

# safety check if we do have a hostname and it differs from requested one
if [ "$HOST" != "$(hostname -s)" ]; then
  read -rp "$(tput setaf 3)This machine reports '$(hostname -s)' but you asked for '$HOST'. Continue?$(tput sgr0) (y/N) " RESP

  if [ "$RESP" != "y" ] && [ "$RESP" != "Y" ]; then
    echo "Aborting."
    exit 0
  fi
fi

# home-manager links ~/.config/home-manager
if [ ! -e ~/.config/home-manager ]; then
  echo "Looks like this host has not been bootstrapped, run ./bootstrap.sh $HOST first"
  exit 1
fi

function gitWrapped() {
  if command -v git &> /dev/null; then
    git "$@"
  elif command -v nix &> /dev/null; then
    nix --extra-experimental-features "nix-command flakes" run nixpkgs#git -- "$@"
  else
    echo "Error: git is not installed and nix is not available as fallback"
    exit 1
  fi
}

function askBeforeRunning() {
  SCRIPT=$1

  read -rp "$(tput setaf 3)Do you want to execute $SCRIPT?$(tput sgr0) (y/N) " RESP
  if [ "$RESP" == "y" ] || [ "$RESP" == "Y" ]; then
    "./$SCRIPT"
  fi
}

mkdir -p "$DOTFILE_DIR/agents/skills-vendor"
pushd "$DOTFILE_DIR/agents/skills-vendor" > /dev/null || exit

gitWrapped clone https://github.com/mattpocock/skills mattpocock-skills

popd > /dev/null || exit

if command -v npm &> /dev/null; then
  askBeforeRunning ./bin/npm-sync
fi

# auth tailscale through the interactive CLI on linux if needed
if [[ $HOST == "minix" || $HOST == "berry" ]] && command -v tailscale &> /dev/null; then
  if tailscale status --json 2> /dev/null | grep -q '"BackendState": *"Running"'; then
    echo "Tailscale already up: $(tailscale status --peers=false 2> /dev/null | awk 'NR==1{print $1, $2}')"
  else
    read -rp "$(tput setaf 3)Log in to tailscale?$(tput sgr0) (y/N) " RESP

    if [ "$RESP" == "y" ] || [ "$RESP" == "Y" ]; then
      sudo tailscale up
    fi
  fi
fi

# auth Dropbox on minix if needed
if [[ $HOST == "minix" ]] && command -v dropbox &> /dev/null; then
  read -rp "$(tput setaf 3)Link Dropbox?$(tput sgr0) (y/N) " RESP

  if [ "$RESP" == "y" ] || [ "$RESP" == "Y" ]; then
    systemctl --user start dropbox 2> /dev/null

    LINKED=""
    for _ in $(seq 30); do
      STATUS="$(dropbox status 2>&1)"

      case $STATUS in
        *cli_link_nonce* | *"To link this computer"*)
          echo
          echo "$STATUS"
          echo
          read -rp "$(tput setaf 3)Press enter once linked$(tput sgr0) " _
          LINKED="yes"
          break
          ;;
        "Dropbox isn't running"*)
          sleep 2
          ;;
        *)
          echo "Dropbox already linked: $STATUS"
          LINKED="yes"
          break
          ;;
      esac
    done

    [ -n "$LINKED" ] || echo "Gave up waiting for dropboxd, check 'dropbox status'"
  fi
fi

if [[ $HOST == "orchid" ]]; then
  # user-level `defaults` live in targets.darwin.defaults (hosts/orchid/home.nix);
  # only sudo-requiring, system-domain macOS setup belongs here
  read -rp "$(tput setaf 3)Pin the hostname and install the ECN-disable daemon?$(tput sgr0) (y/N) " RESP
  if [ "$RESP" == "y" ] || [ "$RESP" == "Y" ]; then
    # pin hostname to lowercase so scripts don't break when DHCP overrides it
    sudo scutil --set HostName orchid

    # disable ECN negotiation - with ECN on, iOS clients could not open TCP
    # connections to this Mac over Tailscale; disabling it fixed that
    sudo tee /Library/LaunchDaemons/com.szymonkaliski.disable-ecn.plist > /dev/null <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>Label</key>
        <string>com.szymonkaliski.disable-ecn</string>
        <key>ProgramArguments</key>
        <array>
            <string>/usr/sbin/sysctl</string>
            <string>-w</string>
            <string>net.inet.tcp.ecn_negotiate_in=0</string>
            <string>net.inet.tcp.ecn_initiate_out=0</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
    </dict>
</plist>
EOF
    sudo chown root:wheel /Library/LaunchDaemons/com.szymonkaliski.disable-ecn.plist
    sudo launchctl bootout system /Library/LaunchDaemons/com.szymonkaliski.disable-ecn.plist 2>/dev/null
    sudo launchctl bootstrap system /Library/LaunchDaemons/com.szymonkaliski.disable-ecn.plist
  fi

  # determinate nix encrypts the /nix volume if the boot disk has FileVault on,
  # which causes a password prompt at every boot, /nix store is public anyway
  # so we can decrypt it
  if [[ "$(diskutil info 'Nix Store' 2>/dev/null | awk -F': +' '/FileVault:/{print $2}')" == "Yes" ]]; then
    read -rp "$(tput setaf 3)Decrypt the Nix Store volume?$(tput sgr0) (y/N) " RESP
    if [ "$RESP" == "y" ] || [ "$RESP" == "Y" ]; then
      security find-generic-password -s "Nix Store" -w /Library/Keychains/System.keychain | sudo diskutil apfs decryptVolume "Nix Store" -stdinpassphrase
    fi
  fi
fi

echo
echo "Done! Restart your machine to make sure everything is loaded correctly."
