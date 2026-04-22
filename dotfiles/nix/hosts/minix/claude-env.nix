{ pkgs, ... }:
{
  # resolved paths for scripts/claude
  environment.variables = {
    CLAUDE_LD = "${pkgs.glibc}/lib/ld-linux-x86-64.so.2";
    CLAUDE_LD_LIBPATH = "${pkgs.glibc}/lib";
  };
}
