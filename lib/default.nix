{
  nixpkgs,
  rockchip,
  home-manager,
  utils,
  settings,
}:

let
  lib = nixpkgs.lib;

  overlayModule =
    { config, lib, ... }:
    {
      nixpkgs.overlays = import ../overlays;
    };

  # Load secrets from companion .secret.nix files for each profile module.
  # Each profile can have e.g. development.secret.nix alongside development.nix.
  # Multiple secret files are merged (later files override earlier keys).
  loadSecrets =
    profilePaths:
    let
      toSecretPath = p: builtins.dirOf (builtins.toString p) + "/secrets.nix";
      secretPaths = builtins.filter builtins.pathExists (builtins.map toSecretPath profilePaths);
      secretAttrs = builtins.map (path: import path) secretPaths;
    in
    builtins.foldl' (acc: s: acc // s) { } secretAttrs;

  # Resolve settings per config name.
  # When configName is null or settings has no `nodes` attr, the raw settings
  # attrset is used (backward compat with flat settings.nix).
  # Otherwise, Common defaults are merged with per-node overrides.
  resolveSettings =
    configName:
    if configName == null || !(settings ? nodes) then
      settings
    else
      let
        common = settings.Common or { };
        node = settings.nodes.${configName} or { };
      in
      common // node;

  # Common base modules shared across all builder types
  baseModules = [
    overlayModule
    home-manager.nixosModules.home-manager
    ../hosts/common/core/default.nix
  ];

  mkSpecialArgs =
    effectiveSettings: secrets: buildPlatform: rockchip:
    if rockchip != null then
      {
        inherit rockchip buildPlatform;
        settings = effectiveSettings;
        inherit secrets;
      }
    else
      {
        inherit buildPlatform;
        settings = effectiveSettings;
        inherit secrets;
      };

in
{
  rockchipOsConfigAarch64 =
    buildPlatform: hostModule: variant: profileModules: configName:
    let
      effectiveSettings = resolveSettings configName;
      secrets = loadSecrets profileModules;
    in
    nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = mkSpecialArgs effectiveSettings secrets buildPlatform rockchip;
      modules =
        baseModules
        ++ [
          { nixpkgs.hostPlatform = "aarch64-linux"; }
          { nixpkgs.buildPlatform = buildPlatform; }
          rockchip.nixosModules.sdImageRockchip
          variant
          hostModule
        ]
        ++ profileModules;
    };

  rockchipInstallerConfigAarch64 =
    buildPlatform: hostModule: profileModules: configName:
    let
      effectiveSettings = resolveSettings configName;
      secrets = loadSecrets profileModules;
    in
    nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = mkSpecialArgs effectiveSettings secrets buildPlatform rockchip;
      modules =
        baseModules
        ++ [
          { nixpkgs.hostPlatform = "aarch64-linux"; }
          { nixpkgs.buildPlatform = buildPlatform; }
          rockchip.nixosModules.sdImageRockchipInstaller
          hostModule
        ]
        ++ profileModules;
    };

  osConfigAarch64 =
    buildPlatform: hostModule: variant: profileModules: configName:
    let
      effectiveSettings = resolveSettings configName;
      secrets = loadSecrets profileModules;
    in
    nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = mkSpecialArgs effectiveSettings secrets buildPlatform null;
      modules =
        baseModules
        ++ [
          { nixpkgs.hostPlatform = "aarch64-linux"; }
          { nixpkgs.buildPlatform = buildPlatform; }
          variant
          hostModule
        ]
        ++ profileModules;
    };

  installerConfigAarch64 =
    buildPlatform: hostModule: profileModules: configName:
    let
      effectiveSettings = resolveSettings configName;
      secrets = loadSecrets profileModules;
    in
    nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = mkSpecialArgs effectiveSettings secrets buildPlatform null;
      modules =
        baseModules
        ++ [
          { nixpkgs.hostPlatform = "aarch64-linux"; }
          { nixpkgs.buildPlatform = buildPlatform; }
          hostModule
        ]
        ++ profileModules;
    };

  installerConfigX86 =
    variant: profileModules: configName:
    let
      effectiveSettings = resolveSettings configName;
      secrets = loadSecrets profileModules;
    in
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = mkSpecialArgs effectiveSettings secrets null null;
      modules =
        baseModules
        ++ [
          { nixpkgs.hostPlatform = "x86_64-linux"; }
          ../hosts/nixos/X86Pc/default.nix
          variant
        ]
        ++ profileModules;
    };
}
