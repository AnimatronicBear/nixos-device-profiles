This is a NixOS definition for the PineTab 2.

To create and 'flash' your installation sd card, change your password
in secrets.nix. If you want to enable remote updates (you probably do),
also include your public key here. then:

```
nix build
dd if=result/sd-image/* of=/dev/of/sd/card bs=4M
```

If you configured a public key, to later update it remotely:

```
nixos-rebuild --flake .#PineTab2 switch --target-host pinetab2@192.168.188.55 --use-remote-sudo --ask-sudo-password
```

If you prefer Plasma to GNOME, use `nix build .#image-plasma` and `.#PineTab2-plasma`. You may need to manually enable the virtual keyboard.
