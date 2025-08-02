{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    nixos-router.url = "github:chayleaf/nixos-router";
    my-nvf.url = "github:silverdev2482/nvf";
    immichUpdatePatch = {
      url = "https://github.com/NixOS/nixpkgs/pull/430306.patch";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      nixpkgs-patched = (import nixpkgs { inherit system; }).applyPatches {
        name = "nixpkgs-patched";
        src = nixpkgs;
        patches = [ inputs.immichUpdatePatch ];
      };
      patchedNixOS = import (nixpkgs-patched + /nixos/lib/eval-config.nix);
    in {
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
      nixosConfigurations = {
        Router-Server = patchedNixOS {
          inherit system;
          specialArgs = {
            inherit inputs;
            addresses = import ./addresses.nix;
          };
          modules = [
            ./minecraft.nix
            ./hardware-configuration.nix
            ./configuration.nix
            ./router.nix
            inputs.nix-minecraft.nixosModules.minecraft-servers
            inputs.nixos-router.nixosModules.default
          ];
        };
      };
    };
}
