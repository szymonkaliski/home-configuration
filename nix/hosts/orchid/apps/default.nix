{
  lib,
  ...
}:
let
  incognitoIcon = ./google-chrome-incognito.png;
  incognitoScript = ''
    do shell script "open -na '/Applications/Google Chrome.app' --args --profile-directory=Default --incognito; sleep 1; open -a 'Google Chrome'"
  '';
  incognitoStamp = builtins.hashString "sha256" "com.szymonkaliski.google-chrome-incognito:${builtins.hashFile "sha256" incognitoIcon}:${incognitoScript}";

  setIcon =
    icon:
    ''/usr/bin/osascript -l JavaScript -e 'ObjC.import("AppKit"); function run(a) { const img = $.NSImage.alloc.initWithContentsOfFile(a[0]); $.NSWorkspace.sharedWorkspace.setIconForFileOptions(img, a[1], 0); }' ${lib.escapeShellArg "${icon}"} "$app" >/dev/null'';
in
{
  # XNU resets TCC responsibility when a launchd shell (/bin/sh, /bin/bash)
  # spawns a non-Apple binary (/nix/store/.../bin/tmux), whereas a Mach-O .app
  # bundle stays responsible for the whole process tree. Built once in place so
  # its ad-hoc CDHash in TCC.db stays stable across home-manager generations.
  home.activation.orchidApps = lib.hm.dag.entryBetween [ "setupLaunchAgents" ] [ "writeBoundary" ] ''
    run rm -rf "$HOME/Applications/Tmux.app"
    app="$HOME/Applications/Launcher.app"
    bin="$app/Contents/MacOS/launcher"
    if [[ ! -x "$bin" ]]; then
      run mkdir -p "$app/Contents/MacOS"
      cat > "$app/Contents/Info.plist" << 'EOF'
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleIdentifier</key>
      <string>com.szymonkaliski.launcher</string>
      <key>CFBundleName</key>
      <string>Launcher</string>
      <key>CFBundleExecutable</key>
      <string>launcher</string>
      <key>CFBundlePackageType</key>
      <string>APPL</string>
      <key>LSUIElement</key>
      <true/>
    </dict>
    </plist>
    EOF
      src="$(/usr/bin/mktemp -t launcher).c"
      cat > "$src" << 'EOF'
    #include <errno.h>
    #include <signal.h>
    #include <sys/wait.h>
    #include <unistd.h>

    static pid_t child = 0;
    static void forward(int sig) {
      if (child > 0) kill(child, sig);
    }

    int main(int argc, char **argv) {
      if (argc < 2) return 1;
      signal(SIGTERM, forward);
      signal(SIGINT, forward);
      child = fork();
      if (child < 0) return 1;
      if (child == 0) {
        execv(argv[1], &argv[1]);
        _exit(1);
      }
      int status = 0;
      while (waitpid(child, &status, 0) < 0 && errno == EINTR) {}
      return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
    }
    EOF
      run /usr/bin/clang -O2 -Wl,-sectcreate,__TEXT,__info_plist,"$app/Contents/Info.plist" "$src" -o "$bin"
      rm -f "$src"
      run /usr/bin/codesign -f -s - --identifier com.szymonkaliski.launcher "$app"
    fi
    if [[ ! -e "$app/Icon"$'\r' ]]; then
      ${setIcon ./launcher.png}
    fi

    app="$HOME/Applications/Google Chrome Incognito.app"
    stampFile="$app/Contents/Resources/.hm-stamp"
    if [[ ! -f "$stampFile" ]] || [[ "$(cat "$stampFile" 2>/dev/null)" != "${incognitoStamp}" ]]; then
      run rm -rf "$app"
      run mkdir -p "$HOME/Applications"
      run /usr/bin/osacompile -o "$app" -e ${lib.escapeShellArg incognitoScript}
      /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.szymonkaliski.google-chrome-incognito" "$app/Contents/Info.plist" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.szymonkaliski.google-chrome-incognito" "$app/Contents/Info.plist"

      tmp="$(/usr/bin/mktemp -d -t applet-icon)"
      iconset="$tmp/applet.iconset"
      mkdir -p "$iconset"
      for s in 16 32 128 256 512; do
        /usr/bin/sips -z "$s" "$s" ${lib.escapeShellArg "${incognitoIcon}"} --out "$iconset/icon_''${s}x''${s}.png" >/dev/null
        s2=$((s * 2))
        /usr/bin/sips -z "$s2" "$s2" ${lib.escapeShellArg "${incognitoIcon}"} --out "$iconset/icon_''${s}x''${s}@2x.png" >/dev/null
      done
      run /usr/bin/iconutil -c icns "$iconset" -o "$app/Contents/Resources/applet.icns"
      rm -rf "$tmp"

      printf '%s' "${incognitoStamp}" > "$stampFile"
      run /usr/bin/codesign -f -s - --identifier com.szymonkaliski.google-chrome-incognito "$app"
      ${setIcon incognitoIcon}
      /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app" >/dev/null 2>&1 || true
    fi
  '';
}
