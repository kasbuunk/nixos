# NixOS Home Lab

This project contains the configuration for Kas Buunk's Home Lab. 

N.B.: This flake may need bootstrapping and may not work for a first installation. The repository must be either cloned or copied over a USB device, where a git clone requires Initial installation of 1Password, git, authentication, and maybe more undocumented steps.

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

## Secret Management

### Generate Key
```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
chown kasbuunk:users ~/.config/sops/age/keys.txt
# Added as secure note in 1Password.
# Note the public key from output (starts with "age1...")
```

### Edit Secrets
```bash
sops secrets.yaml
```

N.B.: Backup `~/.config/sops/age/keys.txt` - without this, secrets cannot be decrypted.

## HTTPS Setup

### Certificate Authority

The homelab uses a self-signed Certificate Authority for internal HTTPS. The CA certificate and key are stored in 1Password.

**Trust the CA on client devices:**
- **macOS:** Double-click `ca.crt` → Keychain Access → Set to "Always Trust"
- **iOS:** AirDrop `ca.crt` → Install Profile → Settings → General → About → Certificate Trust Settings → Enable
- **Windows:** Double-click `ca.crt` → Install → Local Machine → Trusted Root CAs
- **Linux:** `sudo cp ca.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates`
- **Android:** Settings → Security → Install from storage

### Generate Service Certificates

To add HTTPS to a new service:

```bash
cd ~/homelab-ca  # Where CA files are stored

# Create service config (replace SERVICE with service name)
cat > SERVICE.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = SERVICE.home

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = SERVICE.home
DNS.2 = *.SERVICE.home
EOF

# Generate certificate
openssl genrsa -out SERVICE.key 2048
openssl req -new -key SERVICE.key -out SERVICE.csr -config SERVICE.cnf
openssl x509 -req -in SERVICE.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out SERVICE.crt -days 365 -sha256 -extensions v3_req -extfile SERVICE.cnf

# Add to sops secrets.yaml
sops secrets.yaml
# Add SERVICE-tls-key and SERVICE-tls-cert entries
```

## DNS Configuration

### AdGuard Home DNS

The homelab runs AdGuard Home for internal DNS resolution and network-wide ad blocking.

**Access:** `https://adguard.home:3002`

### Configure Network Devices

Set DNS server in UniFi Controller:
1. Open UniFi Network web UI
2. **Settings** → **Networks** → Select your network
3. **DHCP Name Server** → "Manual"
4. DNS Server 1: `192.168.1.76`
5. DNS Server 2: `1.1.1.1` (optional fallback)
6. **Save**

Devices will use `.home` domains after DHCP renewal (reconnect WiFi or wait).

### Add DNS Entries

Add new service DNS entries in AdGuard Home:
1. Go to `https://adguard.home:3002`
2. **Filters** → **DNS rewrites** → **Add DNS rewrite**
3. Domain: `SERVICE.home`, Answer: `192.168.1.76`
4. **Save**

## Services

### Current Services
- **Gitea:** `https://gitea.home:3000` - Git server
- **AdGuard Home:** `https://adguard.home:3002` - DNS and ad blocking
- **PostgreSQL:** Local database (port 5432, unix socket only)

### Service Credentials

All service passwords are managed via sops-nix and stored in `secrets.yaml`. Decrypt with:

```bash
sops secrets.yaml
```

**First-time admin users:**
- Gitea: Auto-created via systemd service using `gitea-admin-password` secret
- AdGuard: Set during initial configuration, stored in service state

## Media

Download media to a directory accessible by Jellyfin. 

Movies: `/var/lib/jellyfin/media/Movies`

## Torrent

Create a directory in `~/Downloads/torrent`, change ownership to transmission:transmission and give it 755 permissions. Otherwise the transmission user cannot write to this directory and still reports success without any logs in journalctl. 

## In progress

Currently I am having trouble setting up the ssh configuration such that I can use 1password from both the nixos server itself and my private device. The issue is that when I am pointing the ssh config to the 1password agent socket, that means it overrides when I connect from a remote device, even with ssh forwarding enabled. So for the time being I set the identity agent with the environment variable `SSH_AUTH_SOCK`, but this only works remotely. I also just created an ssh key for gitea especially so it can use that to authenticate, which works from all devices. But then from the nixos server itself I can't use any ssh keys from 1password. Do I need 1password at all on that machine (programmatically, using the agent socket)?
