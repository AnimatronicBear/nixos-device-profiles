{
  pkgs,
  lib,
  secrets,
  ...
}:
let
  inherit (lib) mkIf;
in
{
  imports = [ 
    ../base/default.nix
    ../development/default.nix
  ];

  environment.systemPackages = with pkgs; [

  ];

  environment.variables = {

  };

  username = "bear";
  hostName = "botany-bay";
}