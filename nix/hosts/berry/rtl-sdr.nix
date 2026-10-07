{ ... }:
{
  # udev rules, plugdev group, DVB driver blacklist, and the rtl-sdr-blog
  # tools (rtl_test, rtl_power), whose driver supports the RTL-SDR Blog V4
  hardware.rtl-sdr.enable = true;

  users.users.szymon.extraGroups = [ "plugdev" ];
}
