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
    gcc
    clang
    llvm
    gdb
    cmake
    ninja
    python3
    nodejs
    rustc
    cargo
    docker-compose
    postgresql
    sqlite
  ];

  environment.variables = {
    GITHUB_TOKEN = mkIf (secrets ? githubToken) secrets.githubToken;
    NPM_TOKEN = mkIf (secrets ? npmToken) secrets.npmToken;
  };
}
