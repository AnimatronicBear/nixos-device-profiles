{
  pkgs,
  lib,
  config,
  settings,
  ...
}:

{
  home.stateVersion = settings.stateVersion;

  home.packages = builtins.map (name: pkgs.${name}) settings.extraUserPackages;

  programs.git = {
    enable = true;
    settings = {
      user.name = settings.gitUserName;
      user.email = settings.gitUserEmail;
      init.defaultBranch = "main";
    };
    signing = {
      key = null;
      signByDefault = false;
    };
  };

  programs.vscodium = {
    enable = true;
    package = pkgs.vscodium;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
      ];
      userSettings = {
      };
    };
  };

  programs.firefox = {
    enable = true;
    package = pkgs.librewolf;
    configPath = ".mozilla/firefox";
    profiles.default = {
      settings = {
      };
    };
  };
}
