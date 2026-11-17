{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-personal.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-personal = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-personal";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-personal, disko, home-manager-personal, plasma-manager, sops-nix, ... }: {
    nixosConfigurations = {
      desktop = nixpkgs-personal.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          home-manager-personal.nixosModules.home-manager
          {
            home-manager.sharedModules = [
              plasma-manager.homeModules.plasma-manager
            ];
          }
          sops-nix.nixosModules.sops
          ./common/default.nix
          ./hosts/desktop/default.nix
        ];
      };

      laptop = nixpkgs-personal.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          home-manager-personal.nixosModules.home-manager
          {
            home-manager.sharedModules = [
              plasma-manager.homeModules.plasma-manager
            ];
          }
          sops-nix.nixosModules.sops
          ./common/default.nix
          ./hosts/laptop/default.nix
        ];
      };

      voron = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          sops-nix.nixosModules.sops
          ./hosts/voron/default.nix
        ];
      };
    };
  };
}
