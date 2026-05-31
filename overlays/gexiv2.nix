# gexiv2 (0.16) fails cross-compilation because -Dgtk_doc=true requires gi-docgen
# as a run-time dependency for the target platform.
final: prev: {
  gexiv2_0_16 = prev.gexiv2_0_16.overrideAttrs (old: {
    mesonFlags = (old.mesonFlags or [ ]) ++ [ "-Dgtk_doc=false" ];
    outputs = builtins.filter (o: o != "devdoc") (
      old.outputs or [
        "out"
        "dev"
        "devdoc"
      ]
    );
    postFixup = "";
  });
}
