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

      # Shorthand: no profiles, no per-node override
      base = dr: dt: myLib.rockchipOsConfigAarch64 "x86_64-linux" dr dt [ ] null;

      # Shorthand: with profiles, no per-node override
      baseWithProfiles =
        dr: dt: profiles:
        myLib.rockchipOsConfigAarch64 "x86_64-linux" dr dt profiles null;
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

      nixosConfigurations = {
        PineBookPro = base ./hosts/nixos/PineBookPro ./hosts/common/optional/gnome.nix;
        PineBookPro-plasma = base ./hosts/nixos/PineBookPro ./hosts/common/optional/plasma.nix;
        PineBookPro-phosh = base ./hosts/nixos/PineBookPro ./hosts/common/optional/phosh.nix;
        PineBookPro-dev = baseWithProfiles ./hosts/nixos/PineBookPro ./hosts/common/optional/gnome.nix [
          ./profiles/base/default.nix
          ./profiles/development/default.nix
        ];
        PineTab2 = base ./hosts/nixos/PineTab2 ./hosts/common/optional/gnome.nix;
        PineTab2-plasma = base ./hosts/nixos/PineTab2 ./hosts/common/optional/plasma.nix;
        PineTab2-phosh = base ./hosts/nixos/PineTab2 ./hosts/common/optional/phosh.nix;
        GenericAarch64 =
          myLib.osConfigAarch64 "x86_64-linux" ./hosts/nixos/GenericAarch64 ./hosts/common/optional/gnome.nix
            [ ]
            null;
        Aarch64LUKSBotanyBay =
          myLib.osConfigAarch64 "aarch64-linux" ./hosts/nixos/Aarch64LUKS ./hosts/common/optional/gnome.nix
            [
              ./profiles/botany-bay/default.nix
            ]
            "Aarch64LUKSBotanyBay";
        CCGenericAarch64BotanyBay =
          myLib.osConfigAarch64 "x86_64-linux" ./hosts/nixos/GenericAarch64 ./hosts/common/optional/gnome.nix
            [
              ./profiles/botany-bay/default.nix
            ]
            "CCGenericAarch64BotanyBay";
        GenericAarch64-installer =
          myLib.installerConfigAarch64 "x86_64-linux" ./hosts/nixos/GenericAarch64 [ ]
            null;
      };
    }
    // utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = nixpkgs.lib;
        checks = import ./checks.nix {
          inherit
            lib
            pkgs
            system
            myLib
            ;
        };
        myPackages = import ./packages.nix {
          inherit
            lib
            pkgs
            system
            myLib
            ;
        };
      in
      {
        packages = myPackages;
        formatter = pkgs.nixfmt-tree;
        checks = checks;
      }
    );
}
