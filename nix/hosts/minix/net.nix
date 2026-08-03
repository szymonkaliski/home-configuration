{
  # microvm bridge network: the host runs the bridge gateway, guests get
  # 10.100.0.<index> on the same /24
  subnet = "10.100.0";
  prefixLength = 24;
  gateway = "10.100.0.254";
}
