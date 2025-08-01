# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{ config, pkgs, lib, inputs, ... }:

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

  services.logrotate.checkConfig = false;
  nixpkgs = {
    config = {
      packageOverrides = pkgs:
        pkgs.lib.recursiveUpdate pkgs {
          linuxKernel.kernels.linux = pkgs.linuxKernel.kernels.linux.override {
            extraConfig = ''
              CONFIG_BCACHEFS_ERASURE_CODING y
            '';
          };
        };
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

  services = {
    ddclient = let
      ipv6sh = pkgs.writeScript "ipv6.sh" ''
        ${pkgs.iproute2}/bin/ip -6 addr show scope global dev lan0 | ${pkgs.gnugrep}/bin/grep inet6 |\
        ${pkgs.gawk}/bin/awk '{print $2}' | ${pkgs.gnugrep}/bin/grep -E ^\(2\|3\) | ${pkgs.coreutils}/bin/cut -d/ -f1
      '';
      ipv4sh = pkgs.writeScript "ipv4.sh" ''
        ${pkgs.iproute2}/bin/ip -4 addr show scope global dev wan0 | ${pkgs.gnugrep}/bin/grep 'inet ' |\
        ${pkgs.gawk}/bin/awk '{print $2}' | ${pkgs.coreutils}/bin/cut -d/ -f1
      '';
    in { 
      enable = true;
      verbose = true;
      domains = [ "dyn.kf0nlr.radio" ];
      usev6 = "cmdv6, cmdv6=${ipv6sh}";
      usev4 = "cmdv4, cmdv4=${ipv4sh}";
      protocol = "dyndns2";
      server = "dyn.dns.he.net";
      interval = "5min";
      username = "dyn.kf0nlr.radio";
      passwordFile = "/srv/secrets/hurricane-electric.pass";
    }; 
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
      cacheNetworks = [
        "127.0.0.0/8"
        "::1"
        "10.48.0.0/16"
        "fd99:2673:4614::/48"
        "2605:4a80:2500:20d0::/60"
      ];
    };
    samba = {
      enable = true;
      settings = {
        global = {
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
      host = "10.48.0.1";
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
        host all all 10.48.0.0/16 scram-sha-256
      '';
    };
    nginx = {
      enable = true;
      virtualHosts."kf0nlr.radio" = {
        root = "/srv/www/";
        enableACME = true;
        addSSL = true;
      };
    };
  };

  security = {
    sudo.wheelNeedsPassword = false;
  };
  security.acme = {
    acceptTerms = true;
    defaults.email = "fidget1206@gmail.com";
  };


  systemd.services = {
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
      };
    };
  };

  users = {
    mutableUsers = false;
    groups = {
      share = { };
      guest = { };
      qbittorrent = {};
      holub = {};
    };
    users = {
      Silverdev2482 = {
        password = "2dEv4wOlf8sIlver2";
        isNormalUser = true;
        extraGroups = [ "wheel" "minecraft" "share" ];
      };
      share = {
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

      orionastraeusantimatter = {
        isNormalUser = true;
        extraGroups = [ "share" ];
      };
      TheRealmer = {
        isNormalUser = true;
        extraGroups = [ "minecraft" "share" ];
      };

      julie = {
        isNormalUser = true;
        extraGroups = [ "share" "holub" ];
      };

    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
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

