final: prev: {
  onnxruntime = prev.onnxruntime.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
      final.pkgsBuildBuild.protobuf
    ];
    cmakeFlags = (old.cmakeFlags or []) ++ [
      "-DONNX_CUSTOM_PROTOC_EXECUTABLE=${final.pkgsBuildBuild.protobuf}/bin/protoc"
    ];
  });
}
