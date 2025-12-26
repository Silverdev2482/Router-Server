{
  description = "A very basic flake";

  inputs = {
    nixpkgs-unpatched.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    nixos-router.url = "github:chayleaf/nixos-router";
    my-nvf.url = "github:silverdev2482/nvf";
    openThreadBoarderRouterInitPatch = {
      url = "https://github.com/NixOS/nixpkgs/pull/332296.patch";
      flake = false;
    };
  };

  outputs = { self, nixpkgs-unpatched, ... }@inputs:
    let
      system = "x86_64-linux";
      nixpkgs = (import nixpkgs-unpatched { inherit system; }).applyPatches {
        name = "nixpkgs";
        src = nixpkgs-unpatched;
        patches = [
          inputs.openThreadBoarderRouterInitPatch
        ];
      };
      patchedNixOS = import (nixpkgs + /nixos/lib/eval-config.nix);
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
            ./dns.nix
            inputs.nix-minecraft.nixosModules.minecraft-servers
            inputs.nixos-router.nixosModules.default
          ];
        };
      };
    };
}
