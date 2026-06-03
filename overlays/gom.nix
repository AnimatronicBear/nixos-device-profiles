final: prev: {
  gom = prev.gom.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.buildPackages.python3 ];
  });
}
