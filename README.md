This is a NixOS definition for the PineTab 2.

To create and 'flash' your installation sd card, change your password
in flake.nix, and:

```
nix build
dd if=result/sd-image/* of=/dev/of/sd/card bs=4M
```

To later update it remotely:

```
nixos-rebuild --flake .#PineTab2 switch --target-host pinetab2@192.168.188.55 --use-remote-sudo
```
