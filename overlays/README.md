# Overlays

## `onnxruntime.nix`

Forces `protoc` to be built for the build platform (`pkgsBuildBuild`) during
cross-compilation. Without this, `cmake` picks up the aarch64 `protoc` from
`nativeBuildInputs`, which cannot run on the x86_64 build host. The error
manifests as a "Protoc binary format error" when cross-building from x86_64 to
aarch64-linux.
