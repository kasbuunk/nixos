# NixOS Home Lab

This project contains the configuration for Kas Buunk's Home Lab. This flake may need bootstrapping and may not work for a first installation. The repository must be either cloned or copied over a USB device, where a git clone requires Initial installation of 1Password, git, authentication, and maybe more undocumented steps.

## Prerequisites

1. Install NixOS on your machine.
1. Install 1Password, authenticate and enable the SSH Agent via Settings -> Developer.
1. Install and be authenticated with git (use 1Password for ssh key management).

## Instructions

1. `mkdir ~/.config && cd ~/.config`
1. Clone this repository inside, such that it resides in `~/.config/nixos`.
1. Remove the files in `/etc/nixos/` (optionally backup).
1. Create symlink to keep `/etc/nixos` non-empty: `sudo ln -s ~/.config/nixos/configuration.nix /etc/nixos/configuration.nix`
1. Run `sudo nixos-rebuild switch --flake ~/.config/nixos
