This is a NixOS definition for the PineTab 2.

## Initial installation

To create and 'flash' your installation sd card, change your password
in secrets.nix. If you want to enable remote updates (you probably do),
also include your public key here. then:

```
nix build
dd if=result/sd-image/* of=/dev/of/sd/card bs=4M
```

## Updating

If you configured a public key, to later update it remotely:

```
nixos-rebuild --flake .#PineTab2 switch --target-host pinetab2@192.168.188.55 --use-remote-sudo --ask-sudo-password
```

If you prefer Plasma to GNOME, use `nix build .#image-plasma` and `.#PineTab2-plasma`. You may need to manually enable the virtual keyboard.

## Updating the u-boot bootloader

`nixos-rebuild` only updates the OS itself, not the u-boot bootloader.
If you want to update the bootloader, pop the sd card into your development machine,
and:

```
$ nix build .#uboot --print-out-paths
$ sudo dd if=/nix/store/your-out-path/u-boot-rockchip.bin of=/dev/your-sd-card conv=fsync,notrunc bs=16M seek=32768 iflag=direct,count_bytes,skip_bytes oflag=direct,seek_bytes
```

(the 32768 here is idbloaderOffset * 512 per https://github.com/nabam/nixos-rockchip/blob/main/modules/sd-card/sd-image-rockchip.nix#L34)

To use this bootloader you need to boot with the [PineTab UART adapter](https://pine64.org/documentation/PineTab2/Development/UART_adapter/)
with the `SD BOOT` switch in the `ON` position.

To install the new bootloader to the pinetab's flash, boot with `SD BOOT` _disabled_ and then:

```
scp u-boot-rockchip-spi.bin pinetab2@192.168.188.55:
ssh pinetab2@192.168.188.55
nix-shell -p mtdutils
flashcp -v -A u-boot-rockchip-spi.bin /dev/mtd0
```
