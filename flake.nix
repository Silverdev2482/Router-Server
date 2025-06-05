{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    nixos-router.url = "github:chayleaf/nixos-router";
    my-nvf.url = "github:silverdev2482/nvf";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let system = "x86_64-linux";
    in {
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
      nixosConfigurations = {
        Router-Server = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
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
