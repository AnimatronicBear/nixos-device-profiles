# git's Rust build scripts need a C compiler for the BUILD platform (x86_64)
# to link the build script executable, but the cross-compilation stdenv only
# provides the HOST platform's compiler (aarch64-*-cc) in PATH.
# Add the build platform's cc to nativeBuildInputs so cargo can find it.
final: prev: {
  git = prev.git.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
      final.buildPackages.stdenv.cc
    ];
  });
}
