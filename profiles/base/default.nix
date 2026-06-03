{ pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    curl
    wget
    htop
    git
    tmux
    vim
    btop
    librewolf
    ungoogled-chromium
  ];
}
