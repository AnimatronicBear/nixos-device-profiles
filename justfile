build host="PineBookPro":
    nix build .#image-{{host}}

check:
    nix flake check

update:
    nix flake update

fmt:
    nix fmt

dev:
    docker compose run dev
