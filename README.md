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
1. Run `sudo nixos-rebuild switch --flake ~/.config/nixos`

## Auto-Update Setup

The system automatically updates daily via a systemd timer. To enable auto-updates, complete these one-time setup steps:

1. Generate SSH deploy key as root:
```bash
   sudo ssh-keygen -t ed25519 -f /root/.ssh/nixos-autoupdate -N ""
```

2. Get the public key:
```bash
   sudo cat /root/.ssh/nixos-autoupdate.pub
```

3. Add the deploy key to GitHub:
   - Navigate to your repository → Settings → Deploy keys → Add deploy key
   - Paste the public key
   - Enable "Allow write access"
   - Save

4. Rebuild to activate the timer:
```bash
   sudo nixos-rebuild switch --flake ~/.config/nixos
```

The system will now check for flake updates daily at midnight, automatically commit and push any changes to `flake.lock`, and rebuild the system configuration.

## Secret management

### Generate key

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
chown kasbuunk:users ~/.config/sops/age/keys.txt

# Added as secure note in 1Password.

# Note the public key from output (starts with "age1...")
```

### Edit secrets

```bash
sops secrets.yaml
```

N.B.: Backup `~/.config/sops/age/keys.txt` - without this, secrets cannot be decrypted.
