# pysmbc's setup.py calls subprocess.Popen(["pkg-config", ...]) but the
# cross-compilation pkg-config-wrapper installs as aarch64-*-pkg-config.
# Create a symlink so the hardcoded name works.
final: prev: {
  python3Packages = prev.python3Packages // {
    pysmbc = prev.python3Packages.pysmbc.overrideAttrs (old: {
      preBuild = (old.preBuild or "") + ''
        pkg_config_bin=$(command -v aarch64-unknown-linux-gnu-pkg-config 2>/dev/null || echo "")
        if [ -n "$pkg_config_bin" ]; then
          ln -sf "$pkg_config_bin" "$TMPDIR/pkg-config"
          export PATH="$TMPDIR:$PATH"
        fi
      '';
    });
  };
}
