# upstream resolvers
#
# blocky forwards to the DoH endpoints and bootstraps them from the ips;
# telegraf pings the ips
{
  quad9 = {
    upstream = "https://dns.quad9.net/dns-query";
    ips = [
      "9.9.9.9"
      "149.112.112.112"
    ];
  };
  cloudflare = {
    upstream = "https://security.cloudflare-dns.com/dns-query";
    ips = [
      "1.1.1.2"
      "1.0.0.2"
    ];
  };
}
