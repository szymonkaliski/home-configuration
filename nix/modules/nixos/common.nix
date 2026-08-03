{ ... }:
{
  # avahi already provides mDNS; disable resolved's so they don't both respond
  services.resolved.settings.Resolve.MulticastDNS = "no";

  # llmnr answers single-label names with link-local addresses, racing magicdns
  services.resolved.settings.Resolve.LLMNR = "no";

  programs.zsh.enable = true;

  # /etc/zshrc otherwise runs a full `compinit` (~40-50ms security audit)
  # before our own; dotfiles/zsh/completion.zsh extends fpath and runs compinit
  # itself, so skip the redundant global one
  programs.zsh.enableGlobalCompInit = false;

  # we set our own PROMPT (dotfiles/zsh/prompt.zsh) and load our own dircolors
  # (deferred, dotfiles/zsh/colors.zsh), so skip /etc/zshrc's `prompt suse`
  # line and its dircolors fork
  programs.zsh.promptInit = "";
  programs.zsh.enableLsColors = false;

  # claude-code ships native binaries, they hardcode the glibc loader path
  programs.nix-ld.enable = true;

  time.timeZone = "Europe/Warsaw";

  nixpkgs.config.allowUnfree = true;

  zramSwap.enable = true;
  zramSwap.algorithm = "zstd";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.gc.automatic = true;
  nix.gc.dates = "weekly";
  nix.gc.options = "--delete-older-than 30d";
}
