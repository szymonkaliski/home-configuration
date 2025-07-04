alias qopen="qlmanage -p "$@" >& /dev/null"

alias clear-logs="sudo rm -rfv /private/var/log/asl/*.asl"
alias clear-tmp="sudo rm -rfv /private/var/tmp/Xcode/ /private/var/tmp/Processing/"
alias clear-dsstore="find . -name '.DS_Store' -depth -exec rm {} \;"

alias flush="dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
alias purge="sudo purge"

alias localip="ipconfig getifaddr en0"
alias opened-ports="sudo lsof -i -P | grep -i 'listen'"
alias stroke="/System/Library/CoreServices/Applications/Network\ Utility.app/Contents/Resources/stroke"
alias airport="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"

alias chrome-kill="ps ux | grep '[C]hrome Helper --type=renderer' | grep -v extension-process | tr -s ' ' | cut -d ' ' -f2 | xargs kill"

alias clout="fc -e - | pbcopy"
alias cpwd="pwd | pbcopy"

# fix for xterm-256color-italic on osx
alias ssh="TERM=xterm-256color ssh"

# fixes for processess getting stuck
alias fix-camera="sudo killall VDCAssistant"
alias fix-icloud="sudo killall cloudd bird"

# apps
if [ -f "/Applications/Fork.app/Contents/Resources/fork_cli" ]; then
  alias fork="/Applications/Fork.app/Contents/Resources/fork_cli"
fi
if [ -f "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ]; then
  alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
fi
if [ -f "/Applications/Cursor.app/Contents/Resources/app/bin/cursor" ]; then
  alias cursor="/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
fi

# cd to currently open dir in finder
cdf() {
  local dir="$(osascript -e 'try' \
    -e 'tell application "Finder" to get POSIX path of (target of front Finder window as text)' \
    -e 'end try')"
  cd "$dir"
}

# shorter open
o() {
  if [ "$#" -ne 0 ]; then
    ARG="${1:+"$@"}"
  else
    ARG="."
  fi

  open $ARG
}

