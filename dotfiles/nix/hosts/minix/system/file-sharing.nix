{
  config,
  pkgs,
  lib,
  ...
}:
{
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish.enable = true;
    publish.addresses = true;
    extraServiceFiles.smb = ''
      <?xml version="1.0" standalone='no'?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name>Minix</name>
        <service>
          <type>_smb._tcp</type>
          <port>445</port>
        </service>
        <service>
          <type>_device-info._tcp</type>
          <port>0</port>
          <txt-record>model=MacPro7,1@ECOLOR=226,226,224</txt-record>
        </service>
      </service-group>
    '';
  };

  services.samba = {
    enable = true;
    settings = {
      global = {
        "server string" = "Minix";
        "server role" = "standalone";
        "netbios name" = "Minix";
        "fruit:aapl" = "yes";
        "fruit:model" = "MacPro7,1";
        "vfs objects" = "fruit streams_xattr";
      };
      homes = {
        browseable = "no";
        writable = "yes";
        "valid users" = "%S";
      };
    };
  };

  sops.secrets.samba_password = { };

  system.activationScripts.samba-password = lib.stringAfter [ "setupSecrets" ] ''
    SMB_PASS=$(cat ${config.sops.secrets.samba_password.path})
    (echo "$SMB_PASS"; echo "$SMB_PASS") | ${pkgs.samba}/bin/smbpasswd -a -s szymon 2>/dev/null
  '';
}
