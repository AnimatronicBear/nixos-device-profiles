{
  inputs = {
    nixpkgsStable.url = "nixpkgs/nixos-25.11";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rockchip = {
      url = "github:nabam/nixos-rockchip";
      inputs.utils.follows = "utils";
      inputs.nixpkgsStable.follows = "nixpkgsStable";
      inputs.nixpkgsUnstable.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rockchip,
      utils,
      home-manager,
      ...
    }:

    let
      lib = nixpkgs.lib;

      settingsFile =
        if builtins.pathExists ./settings.nix then ./settings.nix else ./settings.nix.example;
      settings = import settingsFile;

      myLib = import ./lib {
        inherit
          nixpkgs
          rockchip
          home-manager
          utils
          settings
          ;
      };

      fromVariant = import ./lib/fromVariant.nix {
        inherit lib myLib;
        variantDir = ./variants;
      };

      # nixosConfigurations — top-level, always built from x86_64-linux.
      # ARM variants cross-compile; variants with cross = false build natively
      # (requires aarch64-linux builder or remote builder).
      variantsX86 = fromVariant.buildForSystem "x86_64-linux" nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      nixConfig = {
        max-jobs = 4;
        cores = 0;
        extra-substituters = [
          "https://cache.nixos.org"
          "https://nabam-nixos-rockchip.cachix.org"
        ];
        extra-trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nabam-nixos-rockchip.cachix.org-1:BQDltcnV8GS/G86tdvjLwLFz1WeFqSk7O9yl+DR0AVM"
        ];
      };

      nixosConfigurations = variantsX86.nixosConfigurations;
    }
    // utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        variants = fromVariant.buildForSystem system pkgs;
      in
      {
        packages = variants.packages;
        checks = variants.checks;
        formatter = pkgs.nixfmt-tree;
      }
    );
}
