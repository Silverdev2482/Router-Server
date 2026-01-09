rec {
  

  all = {
    v4Space = "10.48.0.0/16";

    PDPrefix = "2605:4a80:2500:20d";
    PDSpace = all.PDPrefix + "0::/60";
    ULAPrefix = "fd99:2673:4614";
    ULASpace = all.ULAPrefix + "::/48";
  };

  router = {
    v4PublicAddress = "208.107.235.245";

    PDAddress = lan.PDPrefix + "::1";
    PDSpace = lan.PDPrefix + "::/61";
    ULAAddress = lan.ULAPrefix + "::1";
    ULASpace = lan.ULAPrefix + "::/52";
  };

  lan = {
    PDPrefix = all.PDPrefix + "0";
    PDSpace = all.PDPrefix + "0::/64";
    ULAPrefix = all.ULAPrefix + ":0"; # Redundant if you use ::, but kept for caution.
    ULASpace = all.ULAPrefix + "::/64";
  };

  inf = {
    v4Prefix = "10.48.64";
    v4Space = inf.v4Prefix + ".0/18";

    PDPrefix = all.PDPrefix + "1";
    PDSpace = all.PDPrefix + "1::/64";
    ULAPrefix = all.ULAPrefix + ":1";
    ULASpace = all.ULAPrefix + ":1::/64";
  };

  netns = {
    ULAPrefix = all.ULAPrefix + ":4";
    ULASpace = all.ULAPrefix + ":4::/64";
  };



  lanVPN = {
    v4Prefix = "10.48.224";

    ULAPrefix = all.ULAPrefix + ":2";
    ULASpace = all.ULAPrefix + ":2::/64";
  };
  
  wanDirectVPN = {
    v4Prefix = "10.48.128";
    v4Space = "10.48.128.0/24";

    ULAPrefix = all.ULAPrefix + ":3";
    ULASpace = all.ULAPrefix + ":3::/64";
    PDPrefix = all.PDPrefix + "3";
    PDSpace = all.PDPrefix + "3::/64";
  };
  
  russianVPN = {
    v4Prefix = "10.48.160";
    v4Space = "10.48.160.0/24";

    ULAPrefix = all.ULAPrefix + ":4";
    ULASpace = all.ULAPrefix + ":4::/64";
    PDPrefix = all.PDPrefix + "4";
    PDSpace = all.PDPrefix + "4::/64"; 
  };
 



  internalAddresses = [
    "127.0.0.0/8"
    "::1/128"
    all.v4Space
    all.PDSpace
    all.ULASpace
  ];
}
