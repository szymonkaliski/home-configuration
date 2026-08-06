# ssh public keys, named by the machine holding the private half
{
  orchid = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKcLnVCHFI88PfD5qNEjXkerjFLR64LGkixwafkaW4m7 szymon@orchid";
  minix = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJUJt+pQbfy7QwY8EieP5EmX1suXdt9bDECsokG6x/3L szymon@minix";
  berry = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAs/X3At6YhJG9tQGuwJc9PfDdMMkv383zkYWKMtMGeY szymon@berry";

  # berry's nix-daemon, for offloading builds to minix
  # private half in secrets/nix-builder-key
  berryBuilder = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIChQZtjMk5pYpSYFBGUh6jlPU1MfHg+Svpmc7uUzVLlG nix-builder@berry";
  # host key, not a user key - pins minix in berry's known_hosts
  minixHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPHSvjTQM8nV2f3LyMW6H4iuORbvPi+lFRkq2XeGi+VJ root@minix";
  # host key, not a user key - pins berry in minix's known_hosts
  berryHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJlyh3a/IKM22PD9e89/ZllxqehHe9Y8lIwyaWaQt1ZL root@berry";
}
