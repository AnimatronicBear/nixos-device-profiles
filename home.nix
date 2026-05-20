{ pkgs, lib, config, settings, ... }:

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

  # -- Visual Studio Code (VSCodium) ------------------------------------------
  # Extensions are listed under pkgs.vscode-extensions.
  # Run `nix search nixpkgs vscode-extensions` to discover available ones.
  programs.vscodium = {
    enable = true;
    package = pkgs.vscodium;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        # e.g. ms-python.python
        # e.g. rust-lang.rust-analyzer
      ];
      userSettings = {
        # "editor.fontSize" = 14;
        # "workbench.colorTheme" = "Default Dark Modern";
      };
    };
  };

  # -- LibreWolf / Firefox profiles -------------------------------------------
  # LibreWolf ships uBlock Origin by default.
  # To add Mozilla extensions, uncomment below, using packages from
  # pkgs.firefox-addons, e.g.:
  #   extensions = with pkgs.firefox-addons; [ ublock-origin noscript ];
  programs.firefox = {
    enable = true;
    package = pkgs.librewolf;
    # Keep legacy profile path (silences stateVersion < 26.05 warning)
    configPath = ".mozilla/firefox";
    profiles.default = {
      settings = {
        # "privacy.resistFingerprinting" = true;
      };
    };
  };
}
