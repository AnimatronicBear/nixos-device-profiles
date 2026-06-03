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
  imports = [ ../base/default.nix ];

  environment.systemPackages = with pkgs; [
    docker-compose
    docker
    vs-codium
  ];

  environment.variables = {
    # GITHUB_TOKEN = mkIf (secrets ? githubToken) secrets.githubToken;
    # NPM_TOKEN = mkIf (secrets ? npmToken) secrets.npmToken;
  };
}
