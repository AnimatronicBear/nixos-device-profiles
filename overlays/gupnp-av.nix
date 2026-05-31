final: prev:
let
  isCross = final.stdenv.buildPlatform != final.stdenv.hostPlatform;
in
{
  gupnp-av = prev.gupnp-av.overrideAttrs (old: {
    mesonFlags = (old.mesonFlags or [ ]) ++ final.lib.optionals isCross [ "-Dgtk_doc=false" ];
    outputs = if isCross then builtins.filter (o: o != "devdoc") old.outputs else old.outputs;
    postFixup = if isCross then "" else old.postFixup;
  });
}
