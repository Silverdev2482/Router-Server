rec {
  
  all6PDPrefix = "2605:4a80:2500:20d";
  all6PDSpace = all6PDPrefix + "0::/60";
  lan6PDPrefix = all6PDPrefix + "0";
  lan6PDSpace = all6PDPrefix + "0::/64";
  inf6PDPrefix = all6PDPrefix + "1";
  inf6PDSpace = all6PDPrefix + "1::/64";

  router6PDAddress = lan6PDPrefix + "::1";

  all6ULAPrefix = "fd99:2673:4614";
  all6ULASpace = all6ULAPrefix + "::/48";
  lan6ULAPrefix = all6ULAPrefix + ":0"; # Redundant if you use ::, but kept for caution.
  lan6ULASpace = all6ULAPrefix + "::/64";

  inf6ULAPrefix = all6ULAPrefix + ":1";
  inf6ULASpace = all6ULAPrefix + ":1::/64";

  router6ULAAddress = lan6ULAPrefix + "::1";
  
  lanVpn6ULAPrefix = all6ULAPrefix + ":2";
  lanVpn6ULASpace = all6ULAPrefix + ":2::/64";

  wanDirectVpn6ULAPrefix = all6ULAPrefix + ":3";
  wanDirectVpn6ULASpace = all6ULAPrefix + ":3::/64";
  wanDirectVpn6PDPrefix = all6PDPrefix + "3";
  wanDirectVpn6PDSpace = all6PDPrefix + "3::/64";
  
  netns6ULAPrefix = all6ULAPrefix + ":4";
  netns6ULASpace = all6ULAPrefix + ":4::/64";

  all4Space = "10.48.0.0/16";
  router4PublicAddress = "208.107.235.245";
 
  inf4Prefix = "10.48.64";
  inf4Space = inf4Prefix + ".0/18";


  internalAddresses = [
    "127.0.0.0/8"
    "::1/128"
    all4Space
    all6PDSpace
    all6ULASpace
  ];
}
