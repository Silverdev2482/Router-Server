{ config, pkgs, lib, inputs, addresses, ... }:

{

  services = {
    bind = {
      enable = true;
      forwarders = [
        "2606:4700:4700::1111" # Cloudflare main
        "2606:4700:4700::1001" # Cloudflare backup
        "2620:fe::fe" # Quad9 Main
        "2620:fe::9" # Quad9 Backup
        "1.1.1.1" # Cloudflare main
        "1.0.0.1" # Cloudflare backup
        "9.9.9.9" # Quad9 Main
        "149.112.112.112" # Quad9 Backup
      ];
      cacheNetworks = addresses.internalAddresses;
      zones = {
        "kf0nlr.radio" = {
          master = true;
          file = "/etc/bind/zones/kf0nlr.radio.zone";
          # extraConfig = "allow-update { key rfc2136key.${fqdn}.; };";
        };
      };
    };
  };

  networking.nameservers = [ "10.48.0.1" ];

  system.activationScripts.bind-zones.text = ''
    mkdir -p /etc/bind
    chown named:named /etc/bind
  '';

  environment.etc."bind/zones/kf0nlr.radio.zone" = {
    enable = true;
    user = "named";
    group = "named";
    mode = "0644";
    text = ''
      $ORIGIN kf0nlr.radio.
      $TTL      300 ; 5 min
      @         IN      SOA         kf0nlr.radio. fidget1206.gmail.com. (
                        2025081701  ; Serial
                        3h          ; Refresh after 3 hours
                        1h          ; Retry after 1 hour
                        1w          ; Expire after 1 week
                        1h )        ; Negative caching TTL of 1 day

      @         IN      NS      ns1.kf0nlr.crabdance.com.
      @         IN      NS      ns2.kf0nlr.crabdance.com.

      @         IN      A       ${addresses.router4PublicAddress}
      @         IN      AAAA    ${addresses.router6PDAddress}

      dyn       IN      A       ${addresses.router4PublicAddress}
      dyn       IN      AAAA    ${addresses.router6PDAddress}

      astraeus  IN      A       ${addresses.router4PublicAddress}
      astraeus  IN      AAAA    ${addresses.router6PDAddress}

      test      IN      AAAA    ::1

      qbittorrent-public.services IN A    10.48.0.1
      qbittorrent-public.services IN AAAA ${addresses.router6ULAAddress}

      qbittorrent-private.services IN A    10.48.0.1
      qbittorrent-private.services IN AAAA ${addresses.router6ULAAddress}

      home-assistant.services IN A    10.48.0.1
      home-assistant.services IN AAAA ${addresses.router6ULAAddress}

      otbr.services IN A    10.48.0.1
      otbr.services IN AAAA ${addresses.router6ULAAddress}
    '';
  };

}
