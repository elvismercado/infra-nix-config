# SSH client — managed ~/.ssh/config with sensible defaults
# https://man.openbsd.org/ssh_config
#
# Configures the SSH client with agent integration, connection keep-alive,
# and connection reuse. Cross-platform (Linux + macOS).
#
# Host-specific blocks can be added via programs.ssh.matchBlocks in
# the host's home.nix or in this module.
#
# Usage:
#   imports = [ ../../../modules/home-manager/all/ssh.nix ];
#   custom.hmSsh.enable = true;

{
  config,
  lib,
  ...
}:

{
  options = {
    custom.hmSsh.enable = lib.mkEnableOption "SSH client with agent integration, keep-alive, and connection reuse";
  };

  config = lib.mkIf config.custom.hmSsh.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      # Apply sensible defaults to all hosts (Host *)
      matchBlocks."*" = {
        # Auto-add keys to ssh-agent on first use (no manual ssh-add needed)
        addKeysToAgent = "yes";

        # Keep connections alive — prevents idle disconnects (useful for VPS)
        serverAliveInterval = 60;
        serverAliveCountMax = 3;

        # Reuse SSH connections — faster subsequent connections to the same host
        controlMaster = "auto";
        controlPath = "~/.ssh/sockets/%r@%h-%p";
        controlPersist = "10m";

        # Hash known hosts for privacy (hides hostnames in ~/.ssh/known_hosts)
        hashKnownHosts = true;
      };
    };

    # Ensure the ControlPath socket directory exists before ssh tries to bind.
    # Without this, the first connection fails with:
    #   unix_listener: cannot bind to path ~/.ssh/sockets/...: No such file or directory
    home.activation.createSshSocketsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p "$HOME/.ssh/sockets"
      run chmod 700 "$HOME/.ssh/sockets"
    '';
  };
}
