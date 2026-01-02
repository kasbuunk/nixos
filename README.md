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
- Samba (NAS): Network storage at /mnt/nas

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

## VPN

Start VPN with: `sudo systemctl restart wg-quick-wg0`.

Check it's activated in different ways: 

```sh
sudo wg show # Shows interface status, peer, latest handshake time, and transfer amounts.

ip route | grep wg0 # Should show your VPN provider's IP, not your real IP.

curl https://am.i.mullvad.net/json # Tests DNS leak.

curl ifconfig.me # Should show your VPN provider's IP, not your real IP.
```

If sudo wg show shows a recent handshake and curl ifconfig.me shows a different IP than usual, you're connected.

## NAS Setup

The NAS uses an external Samsung T7 SSD. Because this drive often arrives with vendor partitions or ISOs, it must be manually prepared before the NixOS `fileSystems` config can mount it.

### 1. Format the Drive (One-time)

Run these commands to wipe the drive and create a single EXT4 partition labeled `nasdata`:

```bash
nix-shell -p parted e2fsprogs
sudo parted /dev/sda -- mklabel gpt
sudo parted /dev/sda -- mkpart primary ext4 0% 100%
sudo mkfs.ext4 -L nasdata /dev/sda1
exit
```

### 2. Set Permissions

Once NixOS mounts the drive at /mnt/nas, ensure your user owns it:

```bash
sudo chown -R kasbuunk:users /mnt/nas
sudo chmod -R 755 /mnt/nas
```

### 3. Create Samba Password

Samba maintains its own user database. You must manually add your user to it:

```bash
sudo smbpasswd -a kasbuunk
```

Accessing the NAS
From macOS

1. Open Finder and press Cmd + K.

2. Enter smb://nixos.local (or the server IP).

3. Connect as a Registered User using your Linux username and the Samba password created above.

## Home Assistant

Home automation for heating control via OpenTherm Gateway and Zigbee smart radiator thermostats.

**Access:** `https://home.home`

### Hardware

- **SONOFF Zigbee 3.0 USB Dongle Plus** - Zigbee coordinator
- **OpenTherm Gateway WiFi** - Connects to Nefit combi boiler
- **Bosch Smart Home Radiator Thermostat II** (8x) - Smart TRVs

### Setup

#### 1. Plug in Zigbee Dongle

Connect the SONOFF dongle to USB. Verify `/dev/zigbee` symlink exists:
```bash
ls -la /dev/zigbee
```

#### 2. Onboarding

1. Navigate to `https://home.home`
2. Create admin account through the wizard
3. If "Something went wrong" popup appears, hard refresh (Ctrl+Shift+R)

#### 3. Add Zigbee Integration

1. **Settings** → **Devices & Services** → **Add Integration**
2. Search "Zigbee Home Automation" (ZHA)
3. Device path: `/dev/zigbee`
4. Select "SONOFF Zigbee 3.0 USB Dongle Plus"

#### 4. Pair Radiator Thermostats

For each thermostat:
1. **Settings** → **Devices & Services** → **Zigbee Home Automation** → **Add Device**
2. Remove battery cover, press and hold pairing button for 3-5 seconds
3. Device appears within 30 seconds
4. Rename based on room location

#### 5. Configure OpenTherm Gateway

**Physical Installation:**
1. Connect gateway to boiler's OpenTherm port
2. Power via USB-A supply
3. Gateway creates WiFi access point initially

**WiFi Setup:**
1. Connect to gateway's WiFi network
2. Configure to join home network
3. Note assigned IP address

**Home Assistant Integration:**
1. **Settings** → **Devices & Services** → **Add Integration**
2. Search "OpenTherm Gateway"
3. Enter gateway IP (or `otgw.local`)
4. Port: `8080`

## CrowdSec

After applying your configuration.nix changes, the following manual steps are required to finalize the CrowdSec-WireGuard pipeline:
1. Enable WireGuard Debug Logs

By default, WireGuard is silent. You must manually enable kernel dynamic debugging so that handshake failures are sent to the system journal for CrowdSec to read.
Bash

### Enable logging for the wireguard module
echo "module wireguard +p" | sudo tee /sys/kernel/debug/dynamic_debug/control

Note: This kernel setting does not persist across reboots.
2. Register the Security Engine (LAPI)

If this is a fresh install or the credentials file is missing, you must generate the local API credentials.
Bash

### Register the local engine and save credentials to the path defined in your Nix config
sudo cscli machines add local-engine --auto --file /var/lib/crowdsec/local_api_credentials.yaml

### Set correct ownership
sudo chown crowdsec:crowdsec /var/lib/crowdsec/local_api_credentials.yaml
sudo chmod 600 /var/lib/crowdsec/local_api_credentials.yaml

3. Install WireGuard Detection Rules

Download the specific parsers and scenarios required to identify VPN brute-force attempts.
Bash

## # Install the WireGuard collection
sudo cscli collections install crowdsecurity/wireguard

## # Restart the service to apply changes
sudo systemctl restart crowdsec

## In progress

Currently I am having trouble setting up the ssh configuration such that I can use 1password from both the nixos server itself and my private device. The issue is that when I am pointing the ssh config to the 1password agent socket, that means it overrides when I connect from a remote device, even with ssh forwarding enabled. So for the time being I set the identity agent with the environment variable `SSH_AUTH_SOCK`, but this only works remotely. I also just created an ssh key for gitea especially so it can use that to authenticate, which works from all devices. But then from the nixos server itself I can't use any ssh keys from 1password. Do I need 1password at all on that machine (programmatically, using the agent socket)?
