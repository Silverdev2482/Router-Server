{ config, pkgs, lib, inputs24router-lib, ... }:
{

  router.enable = true;

  boot= {
    kernel.sysctl = {
      "net.ipv4.conf.all.forwarding" = true;
      "net.ipv6.conf.all.forwarding" = true;
    };
    kernelModules = [ "sch_cake" ];
  };

  router = {
    interfaces = {
      wan0 = {
        systemdLink.matchConfig.PermanentMACAddress = "d0:50:99:c3:06:d9";
        systemdLink.linkConfig.Name = "wan0";
	dhcpcd.enable = true;
	ipv4.enableForwarding = true;
	ipv6.enableForwarding = true;
      };
      lan0 = {
        systemdLink.matchConfig.PermanentMACAddress = "d0:50:99:c3:06:da";
        systemdLink.linkConfig.Name = "lan0";
	dhcpcd.enable = false;
	ipv4 = {
	  enableForwarding = true;
	  kea = {
	    enable = true;
	    settings = {
	      lease-database = {
	        type = "postgresql";
		name = "kea_dhcp";
		user = "kea";
		password = builtins.readFile ./secrets/kea.password;
	      };
	    };
          };
          addresses = [ { 
            address = "10.48.0.1";
            prefixLength = 17;
            keaSettings = {
	      pools = [
	        { pool = "10.48.1.2 - 10.48.1.254"; }
	      ];
	      reservations = [
	        { hw-address = "48:4d:7e:f9:06:7a"; ip-address = "10.48.0.128"; }
	      ];
	    };
	    dns = [ "1.1.1.1" "1.0.0.1" ];
          } ];
        };
	ipv6 = {
	  enableForwarding = true;
	  radvd = {
	    enable = true;
	  };
	  kea = {
	    enable = true;
	    settings = {
	      lease-database = {
	        type = "postgresql";
		name = "kea_dhcp";
		user = "kea";
		password = builtins.readFile ./secrets/kea.password;
	      };
	    };
          };
	  addresses = [ {
	    address = "fd99:2673:4614:940a::1";
	    prefixLength = 64;
            keaSettings = { pools = [ { pool = "fd99:2673:4614:940a::2 - fd99:2673:4614:940a::ff00"; } ];};
	    dns = [ "2606:4700:4700::1111" "2606:4700:4700::1001" ];
	  } ];
	};
      };
    
      veth0 = {
        ipv4 = {
          addresses = [ {
	    address = "10.48.192.1";
	    prefixLength = 24;
          } ];
        };
        networkNamespace = "default";
      };
      veth1 = {
        ipv4 = {
          addresses = [ {
            address = "10.48.192.2";
	    prefixLength = 24;
          } ];
	  routes = [
	    { extraArgs = "10.48.0.0/17 via 10.48.192.1"; }
	    { extraArgs = "10.48.128.0/18 via 10.48.192.1"; }
	    { extraArgs = "10.48.224.0/19 via 10.48.192.1"; }
	  ];
        };
        networkNamespace = "vpn";
      };
    };
    veths = {
      veth0.peerName = "veth1";
    };
    networkNamespaces = {
      default = {
        nftables.textRules = builtins.readFile ./nftables-default.nft;
 	extraStartCommands = ''
	  # Egress traffic shaping
	  tc qdisc add dev wan0 root cake bandwidth 250mbit internet docsis nat

	  # Allows me to do traffic shaping on ingress
	  ip link add ifb0 type ifb
	  ip link set ifb0 up
	  tc qdisc add dev eth0 handle ffff: ingress
	  sudo tc filter add dev wan0 parent ffff: protocol all u32 match u32 0 0 action mirred egress redirect dev ifb0

	  # Ingress traffic shaping
	  tc qdisc add dev ifb0 root cake bandwidth 250mbit internet docsis nat
	'';
      };
      vpn = {
#        nftables.textRules = builtins.readFile ./nftables-vpn.nft;
        extraStartCommands = ''
	  ip -n vpn link set lo up
	'';
      };
    };
  };

  networking = {
    wireguard.interfaces = {
      commercial-vpn = {
        privateKey = builtins.readFile ./secrets/commercial-vpn.key;

        interfaceNamespace = "vpn";
        ips = [ "10.5.0.2/32" ];
        mtu = 1350;
        peers = [ {
	    publicKey = "VHEKsP+aWtvlhaR1AN8mo1TNOSNJ8knV3kS1vQjN8Rk=";
            endpoint = "181.215.172.180:51820";
            persistentKeepalive = 25;
	    allowedIPs = [ "0.0.0.0/0" "::/0" ];
	} ];
      };
      lan-vpn = {
        privateKeyFile = "/etc/nixos/secrets/router-vpn.key";
	listenPort = 51820;

        ips = [ "10.48.224.1/24" ];
        peers = [
	  {
	    publicKey = "9ebQTGgXBOEVscX6oT/GBQ2MwsQdrtoev22Z1aXb5k8=";
            persistentKeepalive = 25;
	    allowedIPs = [ "10.48.224.2/32" ];
	  }
	  {
	    publicKey = "QCNJ9TUaLSn94UsvlQsdQctzI7SnEdJApf6vSB4/BBg=";
            persistentKeepalive = 25;
	    allowedIPs = [ "10.48.224.3/32" ];
	  }
          {
	    publicKey = "NH4dlhzjZbP1ABYmU//c0fq7prgXtDxbzGLTuWv9Tys=";
            persistentKeepalive = 25;
	    allowedIPs = [ "10.48.224.4/32" ];
	  }
	];
      };
      wan-direct-vpn = {
        privateKeyFile = "/etc/nixos/secrets/router-vpn.key";
	listenPort = 443;
	
	ips = [ "10.48.128.1/24" ];
        peers = [ {
	    publicKey = "9ebQTGgXBOEVscX6oT/GBQ2MwsQdrtoev22Z1aXb5k8=";
            persistentKeepalive = 25;
	    allowedIPs = [ "10.48.128.2/32" ];
	} ];
      };
    };

    hostName = "Router-Server";
    firewall.enable = false;
    nftables.enable = true;
  };

  services = {
    postgresql = {
      enable = true;
      package = pkgs.postgresql_17;
      settings = {
        timezone = "US/Central";
      };
    };
  };

#  # advertise the router, required for ipv6
#  services.radvd = {
#    enable = true;
#    config = ''
#      interface lan0 {
#        AdvSendAdvert on;
#        AdvManagedFlag on;
#        prefix 1111:2222:3333:4444::/64 {
#      AdvAutonomous off;
#        };
#      };
#    '';
#  };


#  boot.kernel.sysctl = {
#    "net.ipv4.conf.all.forwarding" = true;
#    "net.ipv6.conf.all.forwarding" = true;
#    "net.ipv4.conf.default.rp_filter" = 1;
#    "net.ipv4.conf.lan0.rp_filter" = 1;
#    "net.ipv4.conf.wan0.rp_filter" = 1;
#  };

}

