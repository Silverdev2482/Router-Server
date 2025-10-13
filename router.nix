{ config, pkgs, lib, inputs24router-lib, addresses, ... }:

{

  router.enable = true;

  boot = {
    kernel.sysctl = {
      "net.ipv4.conf.all.forwarding" = true;
      "net.ipv6.conf.all.forwarding" = true;
    };
    kernelModules = [ "sch_cake" ];
  };

  hardware.infiniband = {
    enable = true;
    guids = [ "0xf452140300921801" ];
  };

#  systemd.services."opensm@0xf452140300921801".serviceConfig = {
#    ExecStartPre = '' ${pkgs.bash}/bin/bash -c 'while [ "$(cat /sys/class/infiniband/mlx4_0/ports/1/state)" != "1: DOWN"]; do sleep .1; done' '';
#  };


  router = {
    interfaces = {
      wan0 = {
        systemdLink.matchConfig.PermanentMACAddress = "d0:50:99:c3:06:da";
        systemdLink.linkConfig.Name = "wan0";
        dhcpcd = {
          enable = true;
          extraConfig = ''
            noipv6rs
            waitip 6
            interface wan0
              ipv6rs
              iaid 1
              ia_na 1
              ia_pd 2 br0/0/64
              ia_pd 2 ibs1/1/64
              ia_pd 2 wan-direct-vpn/3/64
          '';
        };
        ipv4.enableForwarding = true;
        ipv6.enableForwarding = true;
      };
      lan0 = {
        systemdLink.matchConfig.PermanentMACAddress = "d0:50:99:c3:06:d9";
        systemdLink.linkConfig.Name = "lan0";
        bridge = "br0";
      };
      lan1 = {
        systemdLink.matchConfig.PermanentMACAddress = "f4:52:14:92:18:02";
        systemdLink.linkConfig.Name = "lan1";
        bridge = "br0";
      };
      ibs1 = {
        systemdLink.matchConfig.MACAddress = "80:00:02:18:fe:80:00:00:00:00:00:00:f4:52:14:03:00:92:18:01";
        systemdLink.linkConfig.Name = "ibs1";
        dhcpcd.enable = false;
        ipv4 = {
          addresses = [{
            address = "10.48.64.1";
            prefixLength = 18;
          }];
        };
        ipv6 = {
        # Doesn't work, nor does kea.
          corerad = {
#            enable = true;
            interfaceSettings = {
              prefix = [
                {
                  autonomous = true;
                  prefix = addresses.inf6ULASpace;
                }
                {
                  autonomous = true;
                  prefix = addresses.inf6PDSpace;
                }
              ];
            };
          };
          addresses = [{
            address = addresses.inf6ULAPrefix + "::1";
            prefixLength = 64;
            dns = [ "2606:4700:4700::1111" "2606:4700:4700::1001" ];
            gateways = [{
              address = "fe80::";
              prefixLength = 64;
            }];
          }];
        };
      };
      br0 = {
        dhcpcd.enable = false;
        ipv4 = {
          enableForwarding = true;
          kea = {
            enable = true;
            settings = {
              lease-database = {
                name = "/var/lib/kea/dhcp4.leases";
                persist = true;
                type = "memfile";
              };
              client-classes = [
                {
                  name = "iPXE";
                  test = "option[175].exists";
                  option-data = [
                    {
                      name = "tftp-server-name";
                      data = "10.48.0.1";
                    }
                    {
                      name = "boot-file-name";
                      data = "http://boot.netboot.xyz";
                    }
                  ];
                }
#                {
#                  name = "HTTPClient";
#                  test = "substring(option[vendor-class-identifier].hex,0,10) == 'HTTPClient";
#                  boot-file-name = "https://kf0nlr.radio/ipxe.efi";
#                  option-data = [
#                    {
#                      name = "vendor-class-identifier";
#                      data = "HTTPClient";
#                      always-send = true;
#                    }
#                  ];
#                }
                {
                  name = "UEFI clients";
                  test = "option[93].hex == 0x0007 and not option[175].exists";
                  option-data = [
                    {
#                      code = 66;
                      name = "tftp-server-name";
                      data = "10.48.0.1";
                    }
                    {
#                      code = 67;
                      name = "boot-file-name";
                      data = "ipxe.efi";
                    }
                  ];
                }
                {
                  name = "BIOS clients";
                  test = "option[93].hex == 0x0000 and not option[175].exists";
                  option-data = [
                    {
                      code = 66;
                      name = "tftp-server-name";
                      data = "10.48.0.1";
                    }
                    {
                      code = 67;
                      name = "boot-file-name";
                      data = "undionly.kpxe";
                    }
                  ];
                }
              ];
            };
          };
          addresses = [{
            address = "10.48.0.1";
            prefixLength = 18;
            keaSettings = {
              pools = [{ pool = "10.48.1.2 - 10.48.1.254"; }];
              reservations = [
                { hw-address = "48:4D:7E:F9:06:7A"; ip-address = "10.48.0.128"; }
                { hw-address = "DC:A6:32:14:6F:83"; ip-address = "10.48.0.129"; }
                { hw-address = "D4:5D:64:7B:6B:60"; ip-address = "10.48.0.64"; }
                { hw-address = "0C:9D:92:2C:4D:10"; ip-address = "10.48.0.65"; }
              ];
            };
            dns = [ "1.1.1.1" "1.0.0.1" ];
          }];
          routes = [
            { extraArgs = "10.0.0.0/16 via 10.48.0.3"; }
          ];
        };
        ipv6 = {
          corerad = {
            enable = true;
            interfaceSettings = {
              prefix = [
                {
                  autonomous = true;
                  prefix = addresses.lan6ULASpace;
                }
                {
                  autonomous = true;
                  prefix = addresses.lan6PDSpace;
                }
              ];
            };
          };
          addresses = [{
            address = addresses.lan6ULAPrefix + "::1";
            prefixLength = 64;
            dns = [ "2606:4700:4700::1111" "2606:4700:4700::1001" ];
            gateways = [{
              address = "fe80::";
              prefixLength = 64;
            }];
          }];
        };
      };

      veth0 = {
        ipv4 = {
          addresses = [{
            address = "10.48.192.1";
            prefixLength = 24;
          }];
        };
        ipv6 = {
          addresses = [{
            address = "${addresses.netns6ULAPrefix}::1";
            prefixLength = 64;
          }];
        };
        networkNamespace = "default";
      };
      veth1 = {
        ipv4 = {
          addresses = [{
            address = "10.48.192.2";
            prefixLength = 24;
          }];
          routes = [
            { extraArgs = "10.48.0.0/16 via 10.48.192.1"; }
          ];
        };
        ipv6 = {
          addresses = [{
            address = "${addresses.netns6ULAPrefix}::2";
            prefixLength = 64;
          }];
          routes = [
            { extraArgs = "${addresses.all6ULASpace} via ${addresses.netns6ULAPrefix}::1"; }
            { extraArgs = "${addresses.all6PDSpace} via ${addresses.netns6ULAPrefix}::1"; }
          ];
        };
        networkNamespace = "vpn";
      };
    };
    veths = { veth0.peerName = "veth1"; };
    networkNamespaces = {
      default = {
        nftables.textRules = builtins.readFile ./nftables-default.nft;
        extraStartCommands = ''
          # Egress traffic shaping
          tc qdisc add dev wan0 root cake bandwidth 250mbit internet docsis nftables-default

          # Allows me to do traffic shaping on ingress
          ip link add wan0-ifb type ifb
          ip link set wan0-ifb up
          tc qdisc add dev eth0 handle ffff: ingress
          sudo tc filter add dev wan0 parent ffff: protocol all u32 match u32 0 0 action mirred egress redirect dev wan0-ifb

          # Ingress traffic shaping
          tc qdisc add dev wan0-ifb root cake bandwidth 250mbit internet docsis nat 
        '';
      };
      vpn = {
        #        nftables.textRules = builtins.readFile ./nftables-vpn.nft;
        extraStartCommands = "  ip -n vpn link set lo up";
      };
    };
  };

  networking = {
    wireguard.interfaces = {
      commercial-vpn = {
        privateKey = builtins.readFile "/srv/secrets/commercial-vpn.key";

        interfaceNamespace = "vpn";
        ips = [ "10.150.158.52/32" "fd7d:76ee:e68f:a993:4489:8afd:d99f:4088/128" ];
        peers = [{
          publicKey = "PyLCXAQT8KkM4T+dUsOQfn+Ub3pGxfGlxkIApuig+hk=";
          # us3.ipv6.vpn.airdns.org   dns doesn't resolve early, easier than specifing unit order.
          endpoint = "[2602:fc48:7:0:26b1:de4a:93e0:719c]:51820";
          presharedKey = builtins.readFile "/srv/secrets/commercial-vpn.presharedkey";
          persistentKeepalive = 25;
          allowedIPs = [ "0.0.0.0/0" "::/0" ];
        }];
      };
      lan-vpn = {
        # Public key is: +k1Ly60puFUTM39Ds4efy9ZMoCynnLmu0wErsaJvpls=
        privateKeyFile = "/etc/nixos/secrets/router-vpn.key";
        listenPort = 51820;

        ips = [ "10.48.224.1/24" addresses.lanVpn6ULASpace ];
        peers = [
#          { # Unknown
#            publicKey = "9ebQTGgXBOEVscX6oT/GBQ2MwsQdrtoev22Z1aXb5k8=";
#            persistentKeepalive = 25;
#            allowedIPs = [ "10.48.224.2/32" ];
#          }
#          { # Unknown
#            publicKey = "QCNJ9TUaLSn94UsvlQsdQctzI7SnEdJApf6vSB4/BBg=";
#            persistentKeepalive = 25;
#            allowedIPs = [ "10.48.224.3/32" ];
#          }
          {
            # Cole's PC
            publicKey = "NH4dlhzjZbP1ABYmU//c0fq7prgXtDxbzGLTuWv9Tys=";
            persistentKeepalive = 25;
            allowedIPs = [ "10.48.224.4/32" ];
          }
          {
            # My T14 Gen 2
            publicKey = "2dOocXRe97olfY7mol2Zzgs+Xf37hdU9fZ61OPKC1TY=";
            persistentKeepalive = 25;
            allowedIPs = [ "10.48.224.5/32" (addresses.lanVpn6ULAPrefix + "::5") ];
          }
          {
            # Louis' T480
            publicKey = "/yJI0Y0DrBqE23jnp5WnnhSRpTi+yEv5JIkqXmpWIWk=";
            persistentKeepalive = 25;
            allowedIPs = [ "10.48.224.6/32" ];
          }
          {
            # Mom's phone
            publicKey = "fT8TAqpDhtMvoWfoLfTHgGRL2KPeXIRD1UqqWpABaCc=";
            persistentKeepalive = 25;
            allowedIPs = [ "10.48.224.7/32" ];
          }
          {
            # Joey's PC
            publicKey = "Nbl7jc2zqUz7qDRXd/vm+5ul1c8L49/zFefyYH0aaGk=";
            persistentKeepalive = 25;
            allowedIPs = [ "10.48.224.8/32" ];
          }
          {
            # Louis' PC
            publicKey = "hj4QoLhxembJTBG96+RWTjUZafeNzmz+g04IUr6fP10=";
            persistentKeepalive = 25;
            allowedIPs = [ "10.48.224.9/32" ];
          }
          {
            # orionastraeusantimatter
            publicKey = "+L+zYb9TkNvsbC0/OPcyP919c6AmVtBN7mdYJw63dHA=";
            persistentKeepalive = 25;
            allowedIPs = [ "10.48.224.10/32" ];
          }
          {
            # orionastraeusantimatter
            publicKey = "jdU2IYgl+Ys4wnxwc/iREh26eVJ/UgUbjFKpfd/LVTM=";
            persistentKeepalive = 25;
            allowedIPs = [ "10.48.224.11/32" ];
          }
          {
            # orionastraeusantimatter
            publicKey = "iT66uEL4yy4RXoBSLcBDFYNTB17vLuXpAA4axr9vkBs=";
            persistentKeepalive = 25;
            allowedIPs = [ "10.48.224.12/32" ];
          }
          {
            # Simonette-Server
            publicKey = "dgRQM3/eFf125E5rSt8OHMZ9IJGSO7RFQudHpPF8c2I=";
            persistentKeepalive = 25;
            allowedIPs = [ "10.48.224.13/32" (addresses.lanVpn6ULAPrefix + "::13") ];
          }
        ];
      };
      wan-direct-vpn = {
        privateKey = builtins.readFile "/srv/secrets/router-vpn.key";
        listenPort = 51821;

        ips = [ "10.48.128.1/24" addresses.wanDirectVpn6ULASpace ]; # PD space intentionally excluded
#        ips = [ "10.48.128.1/24" ];
        peers = [
          # My T14 Gen 2
          {
            publicKey = "2dOocXRe97olfY7mol2Zzgs+Xf37hdU9fZ61OPKC1TY=";
            persistentKeepalive = 25;
            allowedIPs = [ "10.48.128.2/32" ];
          }
          {
            publicKey = "Ul0RAdEH1/VuXjDkx8mJN64GbmFVG6znk60B6Uoy3RI=";
            persistentKeepalive = 25;
            allowedIPs = [ "10.48.128.3/32" ];
          }
          {
            # My Pixel 7 Pro
            publicKey = "M5PLr1lMH8b4s6qXgDejOo48iVSi9PjVaPQhFQGIIwM=";
            persistentKeepalive = 25;
            allowedIPs = [ "10.48.128.4/32" "2605:4a80:2500:20d3::4/128" ];
          }

        ];
      };
      # Possibly another vpn to go through commercial vpn again, idk.
    };

    hostName = "Router-Server";
    firewall.enable = false;
    nftables.enable = true;
  };

  services = {
    avahi = {
      enable = true;
      hostName = "Router-Server";
      allowInterfaces = [ "br0" "veth0" ];
      publish = {
        enable = true;
        addresses = true;
        domain = true;
        userServices = true;
      };
    };
    unbound = {
      # Yanked stright from Chayleaf's guide, I don't have a clue how this work
      package =
      # Use python with pydbus and dnspython for Unbound
      let python = pkgs.python3.withPackages (pkgs: with pkgs; [ pydbus dnspython ]);
      in pkgs.unbound-with-systemd.overrideAttrs(old: {
      preConfigure = "export PYTHON_VERSION=${python.pythonVersion}";
      # swig is needed for bindings generation
      nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.swig ];
      buildInputs = old.buildInputs ++ [ python ];
      configureFlags = old.configureFlags ++ [ "--with-pythonmodule" ];
      # Patch makefile to use correct output directory
      postPatch = (old.postPatch or "") + ''
      substituteInPlace Makefile.in \
        --replace "\$(DESTDIR)\$(PYTHON_SITE_PKG)" "$out/${python.sitePackages}"
      '';
      # Export correct PYTHONPATH for the resulting unbound binary
      # Namely, export both the output module generated by Unbound,
      # and the modules bundled with the Python defined above
      postInstall = old.postInstall + ''
        wrapProgram $out/bin/unbound \
          --prefix PYTHONPATH : "$out/${python.sitePackages}" \
          --prefix PYTHONPATH : "${python}/${python.sitePackages}" \
          --argv0 $out/bin/unbound
      '';
      });
#      enable = true;
    };


    #postgresql = {
    #  enable = true;
    #  package = pkgs.postgresql_17;
    #  settings = { timezone = "US/Central"; };
    #};
  };
}
