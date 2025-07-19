rec {
  all6PDPrefix = "2605:4a80:2500:20d";
  lan6PDPrefix = all6PDPrefix + "0";
  lan6PDSpace = all6PDPrefix + "0::/64";

  all6ULAPrefix = "fd99:2673:4614";
  all6ULASpace = all6ULAPrefix + "::/48";
  lan6ULAPrefix = all6ULAPrefix + ":0"; # Redundant if you use ::, but kept for caution.
  lan6ULASpace = all6ULAPrefix + "::/64";
  
  lanVpn6ULAPrefix = all6ULAPrefix + ":10";
  lanVpn6ULASpace = all6ULAPrefix + ":10::/64";

  wanDirectVpn6ULAPrefix = all6ULAPrefix + ":11";
  wanDirectVpn6ULASpace = all6ULAPrefix + ":11::/64";
  wanDirectVpn6PDPrefix = all6PDPrefix + "1";
  wanDirectVpn6PDSpace = all6PDPrefix + "1::/64";

}
