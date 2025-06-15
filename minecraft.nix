{ config, pkgs, lib, inputs, ... }:
{
  nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];
  services.minecraft-servers = {
    enable = true;
    eula = true;
    dataDir = "/srv/minecraft/";
    servers.survival =
      let
        modpack = pkgs.fetchPackwizModpack {
          url = "https://raw.githubusercontent.com/Silverdev2482/New-mods/master/pack.toml";
          packHash = "sha256-UC/P7A5vspYL12MENhP43zx0etrZ8DoTdsyRzo4Y4GM=";
        };
        mcVersion = modpack.manifest.versions.minecraft;
        fabricVersion = modpack.manifest.versions.fabric;
        serverVersion = lib.replaceStrings [ "." ] [ "_" ] "fabric-${mcVersion}";
      in
      {
        enable = true;
	      path = [ pkgs.git pkgs.git-lfs ];
        autoStart = true;
        jvmOpts = "-Xmx10240M -Xms512M";
        package = pkgs.fabricServers.${serverVersion}.override { loaderVersion = fabricVersion; };
        symlinks = {
          "mods" = "${modpack}/mods";
        };
      };
    servers.creative =
      let
        modpack = pkgs.fetchPackwizModpack {
          url = "https://raw.githubusercontent.com/Silverdev2482/Survival-mods/main/pack.toml";
          packHash = "sha256-BqWVOhcZxy91A7IZsd8uTA5Sqe27CrEWd+iNIoEffaA=";
        };
        mcVersion = modpack.manifest.versions.minecraft;
        fabricVersion = modpack.manifest.versions.fabric;
        serverVersion = lib.replaceStrings [ "." ] [ "_" ] "fabric-${mcVersion}";
      in
      {
        enable = false;
	      path = [ pkgs.git pkgs.git-lfs ];
        autoStart = false;
        jvmOpts = "-Xmx2048M -Xms1024M";
        package = pkgs.fabricServers.${serverVersion}.override { loaderVersion = fabricVersion; };
        symlinks = {
          "mods" = "${modpack}/mods";
        };
      };
 };
} 
