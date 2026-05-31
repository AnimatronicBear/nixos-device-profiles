# libglycin uses meson + cargo for its Rust subproject. The meson version
# in this nixpkgs doesn't pass --target to cargo during cross-compilation,
# so cargo builds for the build platform (x86_64) instead of the host
# platform (aarch64). Set CARGO_BUILD_TARGET to fix this.
final: prev: {
  libglycin = prev.libglycin.overrideAttrs (old: {
    CARGO_BUILD_TARGET = "aarch64-unknown-linux-gnu";
  });
}
