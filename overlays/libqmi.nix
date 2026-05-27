final: prev: {
  libqmi = prev.libqmi.overrideAttrs (old: {
    mesonFlags = (old.mesonFlags or [ ]) ++ [
      "-Dgtk_doc=false"
    ];
  });
}
