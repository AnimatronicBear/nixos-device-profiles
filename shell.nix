{
  pkgs ? import <nixpkgs> { },
}:

pkgs.mkShell {
  packages = with pkgs; [
    nixfmt-tree
    nix-output-monitor
  ];
}
