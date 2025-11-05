# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{ config, pkgs, lib, inputs, addresses, ... }:

{
  boot = {
    supportedFilesystems = [ "bcachefs" ];
    loader = {
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        extraConfig = "serial --speed=115200 --unit=1 --word=8 --parity=no --stop=1; terminal_input serial; terminal_output serial";
      };
      efi.canTouchEfiVariables = true;
    };
    kernelModules = [ "lanplus" ];
    kernelParams = [ "console=tty1" "console=ttyS1,115200n8" ];
  };
  systemd.services."serial-getty@ttyS1" = {
    enable = true;
    wantedBy = [ "getty.target" ];
    serviceConfig.Restart = "always";
  };

  nixpkgs = {
    config = {
      packageOverrides = pkgs:
        pkgs.lib.recursiveUpdate pkgs {
          linuxKernel.kernels.linux = pkgs.linuxKernel.kernels.linux.override {
            extraConfig = ''
              CONFIG_BCACHEFS_ERASURE_CODING y
            '';
          };
        };#
        allowUnfree = true;
      };
    };


  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    extra-sandbox-paths = [ "/srv/secrets" ];
  };

  time.timeZone = "US/Central";

  security.polkit = {
    enable = true;
    extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "minecraft-server-survival.service" &&
          subject.isInGroup == "minecraft") {
            return polkit.Result.YES;
          }
        }
      );
    '';
  };

  systemd = {
    timers.ddns = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/5";
        AccuracySec = "5sec";
      };
    };
    services.ddns = let
      ddns = pkgs.writeScript "ddns.sh" ''
        #!${pkgs.bash}/bin/bash
        echo "Finding IPs"
        export ipv6=$(${pkgs.iproute2}/bin/ip -6 addr show scope global dev br0 | ${pkgs.gnugrep}/bin/grep inet6 |\
        ${pkgs.gawk}/bin/awk '{print $2}' | ${pkgs.gnugrep}/bin/grep -E ^\(2\|3\) | ${pkgs.coreutils}/bin/cut -d/ -f1)
        export ipv4=$(${pkgs.iproute2}/bin/ip -4 addr show scope global dev wan0 | ${pkgs.gnugrep}/bin/grep 'inet ' |\
        ${pkgs.gawk}/bin/awk '{print $2}' | ${pkgs.coreutils}/bin/cut -d/ -f1)
      
        echo "ipv6 is: ''${ipv6}"
        echo "ipv4 is: ''${ipv4}"

        echo "Updating DNS"

        ${pkgs.curl}/bin/curl "https://dyn.dns.he.net/nic/update" -d "hostname=dyn.kf0nlr.radio" -d "password=$(</srv/secrets/hurricane-electric.pass)" -d "myip=''${ipv6}"
        echo
        ${pkgs.curl}/bin/curl "https://dyn.dns.he.net/nic/update" -d "hostname=dyn.kf0nlr.radio" -d "password=$(</srv/secrets/hurricane-electric.pass)" -d "myip=''${ipv4}"
        echo

        echo "Exiting"
      '';
    in {
      serviceConfig = {
        ExecStart = ddns;
      };
    };
  };

  services = {
    openthread-border-router = {
      enable = true;
      backboneInterface = "br0";
      radio = {
        url = "spinel+hdlc+uart:///tmp/ttyOTBR";
      };
      web = {
        enable = true;
        listenAddress = "::1";
        listenPort = 8082;
      };
    };
    matter-server.enable = true;
    logrotate.checkConfig = false;
    mosquitto = {
      enable = true;
      listeners = [
        {
          acl = [ "pattern readwrite #" ];
          omitPasswordAuth = true;
          settings.allow_anonymous = true;
        }
      ];
    };

    home-assistant = {
      enable = true;
      extraComponents = [
        # Components required to complete the onboarding
        "analytics"
        "google_translate"
        "met"
        "mqtt"
        "tasmota"
        "esphome"
        "otbr"
        "thread"
        "matter"
        "smlight"
        "radio_browser"
        "shopping_list"
        # Recommended for fast zlib compression
        # https://www.home-assistant.io/integrations/isal
        "isal"
      ];
      config = {
        # Includes dependencies for a basic setup
        # https://www.home-assistant.io/integrations/default_config/
        default_config = {};
        http = {
          server_host = "::1";
          trusted_proxies = [ "::1" ];
          use_x_forwarded_for = true;
        };
        "automation ui" = "!include automations.yaml";
        "scene ui" = "!include scenes.yaml";
        "script ui" = "!include scripts.yaml";
      };
    };
    nfs = {
      settings.nfsd.rdma = true;
      server = {
#        extraNfsdConfig = "rdma = yes";
        enable = true;
        exports = "
          /srv/shares ${addresses.inf4Space}(rw,insecure,async,no_root_squash,acl)
          /srv/shares ${addresses.inf6ULASpace}(rw,insecure,async,no_root_squash,acl)
        ";
      };
    };
    tftpd.enable = true;
    samba = {
      enable = true;
      settings = {
        global = {
          "unix charset" = "UTF-8";
          "mangled names" = "no";
          "unix extensions" = "yes";
          "allow insecure wide links" = "yes";
          # This is safe if you would trust all users with access to this file
          # server with ssh access to their own user account.
          "workgroup" = "WORKGROUP";
          "server string" = "smbnix";
          "netbios name" = "smbnix";
          "security" = "user";
          # Won't let me change the capitalization to something else if I keep
          # the same name without forcing case sensitivity
          "case sensitive" = "yes";
          "guest account" = "nobody";
          "map to guest" = "bad user";
          # Apple is more retarded than even me
          "vfs objects" = "fruit streams_xattr";
          "nt acl support" = "no";
        };
        "shares" = {
          "wide links" = "yes";
          "follow symlinks" = "yes";
          "path" = "/srv/shares/";
          "browseable" = "yes";
          "read only" = "no";
          "guest ok" = "no";
        };
      };
    };
    samba-wsdd.enable = true;
    smartd = { enable = true; };
    immich = {
      enable = true;
      host = "";
    };
    jellyfin.enable = true;
    pixiecore = {
      enable = false;
      dhcpNoBind = true;
      kernel = "https://boot.netboot.xyz";
    };
    postgresql = {
      enable = true;
      enableTCPIP = true;
      settings.timezone = "US/Central";
      authentication = ''
        host all all 127.0.0.0/8 scram-sha-256
        host all all ::1/128 scram-sha-256
        host all all ${addresses.all4Space} scram-sha-256
        host all all ${addresses.all6PDSpace} scram-sha-256
        host all all ${addresses.all6ULASpace} scram-sha-256
      '';
    };
    nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts = {
        "kf0nlr.radio" = {
          root = "/srv/www/";
          forceSSL = true;
          useACMEHost = "kf0nlr.radio";
        };
        "astraeus.kf0nlr.radio" = {
          root = "/home/Astraeus/www/";
          forceSSL = true;
          useACMEHost = "kf0nlr.radio";
        };
        "qbittorrent-private.services.kf0nlr.radio" = {
          forceSSL = true;
          useACMEHost = "kf0nlr.radio";
          locations."/" = {
            proxyPass = "http://[fd99:2673:4614:4::2]:56080/";
            extraConfig = ''
              allow 127.0.0.0/8; 
              allow ::1/128;
              allow ${addresses.all4Space};
              allow ${addresses.all6PDSpace};
              allow ${addresses.all6ULASpace};
              deny all; # Deny all other IPs
              
              # headers recognized by qBittorrent
              proxy_set_header   Host               $proxy_host;
              proxy_set_header   X-Forwarded-For    $proxy_add_x_forwarded_for;
              proxy_set_header   X-Forwarded-Host   $http_host;
              proxy_set_header   X-Forwarded-Proto  $scheme;
            '';
          };
        };
        "qbittorrent-public.services.kf0nlr.radio" = {
          forceSSL = true;
          useACMEHost = "kf0nlr.radio";
          locations."/" = {
            proxyPass = "http://[fd99:2673:4614:4::2]:8080/";
            extraConfig = ''
              allow 127.0.0.0/8; 
              allow ::1/128;
              allow ${addresses.all4Space};
              allow ${addresses.all6PDSpace};
              allow ${addresses.all6ULASpace};
              deny all; # Deny all other IPs
              
              # headers recognized by qBittorrent
              proxy_set_header   Host               $proxy_host;
              proxy_set_header   X-Forwarded-For    $proxy_add_x_forwarded_for;
              proxy_set_header   X-Forwarded-Host   $http_host;
              proxy_set_header   X-Forwarded-Proto  $scheme;
            '';
          };
        };
        "home-assistant.services.kf0nlr.radio" = {
          forceSSL = true;
          useACMEHost = "kf0nlr.radio";
          locations."/" = {
            proxyPass = "http://[::1]:8123/";
            proxyWebsockets = true;
            extraConfig = ''
              allow 127.0.0.0/8; 
              allow ::1/128;
              allow ${addresses.all4Space};
              allow ${addresses.all6PDSpace};
              allow ${addresses.all6ULASpace};
              deny all; # Deny all other IPs
            '';
          };
        };
        "otbr.services.kf0nlr.radio" = {
          forceSSL = true;
          useACMEHost = "kf0nlr.radio";
          locations."/" = {
            proxyPass = "http://[::1]:8082/";
            proxyWebsockets = true;
            extraConfig = ''
              allow 127.0.0.0/8; 
              allow ::1/128;
              allow ${addresses.all4Space};
              allow ${addresses.all6PDSpace};
              allow ${addresses.all6ULASpace};
              deny all; # Deny all other IPs
            '';
          };
        };
      };
    };
  };

  security = {
    sudo.wheelNeedsPassword = false;
  };
  security.acme = {
    acceptTerms = true;
    certs."kf0nlr.radio" = {
      group = "nginx";
      email = "fidget1206@gmail.com";
      dnsResolver = "1.1.1.1";
      dnsProvider = "hurricane";
      dnsPropagationCheck = false;
      environmentFile = "/srv/secrets/certs";
      extraDomainNames = [
        "*.kf0nlr.radio"
        "*.services.kf0nlr.radio"
      ]; 
    };
  };


  systemd.services = {
    otbr-network = {
      description = "otbr network to tty";
      requires = [ "network-online.target" ];
      after = [ "network-online.target" ];
      wantedBy = [ "otbr-agent.service" ];
      before = [ "otbr-agent.service" ];
      path = [pkgs.socat];
      script = ''
        socat -d pty,raw,echo=0,link=/tmp/ttyOTBR,ignoreeof "tcp:10.48.0.34:6638"
      '';
    };
    qBittorrent-public = {
      # based on the plex.nix service module and
      # https://github.com/qbittorrent/qBittorrent/blob/master/dist/unix/systemd/qbittorrent-nox%40.service.in
      description = "qBittorrent-nox service for public trackers";
      documentation = [ "man:qbittorrent-nox(1)" ];
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "qbittorrent";
        ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox --profile=/var/lib/qBittorrent-public";
        NetworkNamespacePath = "/run/netns/vpn";
      };
    };
    qBittorrent-private = {
      description = "qBittorrent-nox service for private trackers";
      documentation = [ "man:qbittorrent-nox(1)" ];
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "qbittorrent";
        ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox --profile=/var/lib/qBittorrent-private --webui-port=56080";
        NetworkNamespacePath = "/run/netns/vpn";
      };
    };
  };

  users = {
    mutableUsers = true;
    groups = {
      share = {
        gid = 994;
      };
      guest = { };
      qbittorrent = {};
      holub = {};
    };
    users = {
      Silverdev2482 = {
        isNormalUser = true;
        extraGroups = [ "rdma" "wheel" "minecraft" "share" "nginx" ];
      };
      share = {
        isSystemUser = true;
        group = "share";
      };
      borg = {
        isSystemUser = true;
        group = "share";
      };
      qbittorrent = {
        isSystemUser = true;
        group = "qbittorrent";
        extraGroups = [ "share" ];
      };
      jellyfin = {
        isSystemUser = true;
        extraGroups = [ "share" ];
      };

      royalspade = {
        isNormalUser = true;
        extraGroups = [ "share" ];
      };
      stuffedcrust = {
        isNormalUser = true;
        extraGroups = [ "share" ];
      };
      joey = {
        isNormalUser = true;
        extraGroups = [ "share" ];
      };

      Astraeus = {
        isNormalUser = true;
        extraGroups = [ "share" ];
      };
      TheRealmer = {
        isNormalUser = true;
        extraGroups = [ "minecraft" "share" ];
      };

      Julie = {
        isNormalUser = true;
        extraGroups = [ "share" "holub" ];
      };

    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    qperf
    pciutils
    rdma-core
    yt-dlp
    rsync
    irssi
    jdk21_headless
    znc
    python314
    unison
    inputs.my-nvf.packages.x86_64-linux.default
    harper
    wget
    tmux
    smartmontools
    kea
    zip
    unzip
    git-lfs
    git
    gitui
    packwiz
    fastfetch
    btop
  ];

  services.openssh.enable = true;
  programs.mosh.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}

