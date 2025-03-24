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
      };
      efi.canTouchEfiVariables = true;
    };
  };

  nixpkgs.config.packageOverrides = pkgs:
    pkgs.lib.recursiveUpdate pkgs {
      linuxKernel.kernels.linux = pkgs.linuxKernel.kernels.linux.override {
        extraConfig = ''
          CONFIG_BCACHEFS_ERASURE_CODING y                                                                
        '';
      };
    };

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    extra-sandbox-paths = [ "/srv/secrets" ];
  };

  time.timeZone = "US/Central";

  services = {
    samba = {
      enable = true;
      settings = {
        global = {
          "workgroup" = "WORKGROUP";
          "server string" = "smbnix";
          "netbios name" = "smbnix";
          "security" = "user";
          # note: localhost is the ipv6 localhost ::1
          "hosts allow" = "10.48.0.0/16 localhost";
          "guest account" = "nobody";
          "map to guest" = "bad user";
          # Apple is more retarded than even me
          "vfs objects" = "fruit streams_xattr";
          "nt acl support" = "no";
        };
        "shares" = {
          "path" = "/srv/shares/";
          "browseable" = "yes";
          "read only" = "no";
          "guest ok" = "no";
        };
      };
    };
    samba-wsdd.enable = true;
    avahi = {
      enable = true;
      hostName = "Router-Server";
      allowInterfaces = [ "lan0" "veth0" ];
      publish = {
        enable = true;
        userServices = true;
      };
    };

    geoipupdate = {
      enable = true;
      settings = {
        AccountID = 1116655;
        LicenseKey = { _secret = "/srv/secrets/geoip.key"; };
        EditionIDs = [ "GeoLite2-Country" ];
      };
    };

    smartd = { enable = true; };
    jellyfin.enable = true;
  };

  systemd.services = {
    qbittorrent = {
      # based on the plex.nix service module and
      # https://github.com/qbittorrent/qBittorrent/blob/master/dist/unix/systemd/qbittorrent-nox%40.service.in
      description = "qBittorrent-nox service";
      documentation = [ "man:qbittorrent-nox(1)" ];
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "qbittorrent";
        ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox --profile=/var/lib";
        NetworkNamespacePath = "/run/netns/vpn";
      };
    };
  };


  users = {
    mutableUsers = true;
    groups = {
      share = { };
      qbittorrent = {};
      holub = {};
    };
    users = {
      silverdev2482 = {
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


      julie = {
        isNormalUser = true;
        extraGroups = [ "share" "holub" ];
      };

    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    python314
    unison
    inputs.my-nvf.packages.x86_64-linux.default
    wget
    tmux
    smartmontools
    kea
    zip
    git-lfs
    git
    packwiz
    neofetch
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

