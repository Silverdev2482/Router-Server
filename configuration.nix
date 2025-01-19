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

  nixpkgs.config.packageOverrides = pkgs: pkgs.lib.recursiveUpdate pkgs {                               
    linuxKernel.kernels.linux = pkgs.linuxKernel.kernels.linux.override {                               
      extraConfig = ''                                                                                  
        CONFIG_BCACHEFS_ERASURE_CODING y                                                                
      '';                                                                                               
    };                                                                                                  
  };


  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  time.timeZone = "US/Central";

  services = {
    deluge = {
      enable = true;
      web.enable = true;
      package = pkgs.deluge-2_x;
    };
    samba = {
      enable = true;
      securityType = "user";
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

    kerberos_server = {
      enable = true;
      settings = {
        realms."SILVERDEV.LOCAL" = {
        };
      };
    };

    smartd = {
      enable = true;
    };
    jellyfin.enable = true;
  };

  security.krb5 = {
    enable = true;
    settings = {
      libdefaults.default_realm = "SILVERDEV.LOCAL";
      realms."SILVERDEV.LOCAL" = {
        kdc = "10.48.0.1";
        admin_server = "10.48.0.1";
	auth_to_local = "DEFAULT";
      };
    };
  };

  systemd.services = {
    deluged.serviceConfig.NetworkNamespacePath = "/run/netns/vpn";
    delugeweb.serviceConfig.NetworkNamespacePath = "/run/netns/vpn";
  };

  users = {
    mutableUsers = true;
    groups = {
      share = {};
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
      deluge = {
	isSystemUser = true;
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


    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
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
  system.stateVersion = "unstable"; # Did you read the comment?

}

