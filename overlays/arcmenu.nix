final: prev: {
  gnomeExtensions = prev.gnomeExtensions // {
    arc-menu = prev.gnomeExtensions.arc-menu.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
        final.buildPackages.glib
        final.buildPackages.gitMinimal
      ];
    });
  };
}
