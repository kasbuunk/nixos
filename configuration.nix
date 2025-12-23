# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let
  cfg = import ./variables.nix;
in

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Secret management.
  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.keyFile = "/home/kasbuunk/.config/sops/age/keys.txt";

    secrets = {
      postgres-admin-password = {
        owner = "postgres";
      };
      postgres-gitea-password = {
        owner = "gitea";
      };
      gitea-admin-password = {
        owner = "gitea";
      };

      # TLS certificates
      gitea-tls-key = {
        owner = "gitea";
        mode = "0400";
      };
      gitea-tls-cert = {
        owner = "gitea";
        mode = "0444";
      };
      adguard-tls-key = {
        owner = "adguardhome";
        mode = "0400";
      };
      adguard-tls-cert = {
        owner = "adguardhome";
        mode = "0444";
      };
      wireguard-private-key = {
        owner = "systemd-network";
        mode = "0400";
      };
    };
  };

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/nvme0n1";
  boot.loader.grub.useOSProber = true;

  # Setup keyfile
  boot.initrd.secrets = {
    "/boot/crypto_keyfile.bin" = null;
  };

  boot.initrd.luks.devices."luks-bb4c75e7-5ece-4105-9647-6494eb386af4".keyFile = "/boot/crypto_keyfile.bin";

  boot.loader.grub.enableCryptodisk = true;

  boot.supportedFilesystems = [ "zfs" ];
  networking.hostId = "02ba2494"; # Required for ZFS.

  services.zfs.autoScrub.enable = true; # Keeping data healthy.

  networking = {
    hostName = "nixos"; # Define your hostname.

    # Enables wireless support via wpa_supplicant.
    # This is mutually exlusive from the networkmanager below (I think).
    # wireless.enable = true;  

    # Wake up server by sending a packet.
    interfaces.${cfg.network.interface} = {
      ipv4.addresses = [{
        address = cfg.network.hostIp;
        prefixLength = 24;
      }];

      wakeOnLan.enable = true;
    };

    # Enable networking
    networkmanager.enable = true;

    defaultGateway = cfg.network.gateway;
    nameservers = [ cfg.network.dns ]; # Cloudflare's DNS.

    # Configure network proxy if necessary
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # Open ports in the firewall.
    firewall = {
      enable = true;
      allowedTCPPorts = [
        cfg.services.ssh.port
        # Expose internal services here.
        cfg.services.gitea.httpPort
        cfg.services.gitea.sshPort
        cfg.services.adguard.httpPort
        cfg.services.adguard.httpsPort
        cfg.services.adguard.dnsPort
        cfg.services.adguard.dnsOverTLSPort
        cfg.services.jellyfin.httpPort
        cfg.nas.tcp1
        cfg.nas.tcp2
      ];
      allowedUDPPorts = [
        cfg.services.adguard.dnsPort
        cfg.nas.udp1
        cfg.nas.udp2
      ];
    };

    # Or disable the firewall altogether.
    # networking.firewall.enable = false;

    wg-quick.interfaces = {
      wg0 = {
        address = [ "10.2.0.2/32" ];
        dns = [ "10.2.0.1" ];
        privateKeyFile = config.sops.secrets.wireguard-private-key.path;
        
        peers = [{
          publicKey = "5pQdM0t5q7L83x58nIkdy8Nx6lfkBj0AB2MkuVqWeFE=";
          allowedIPs = [ "0.0.0.0/0" "::/0" ];
          endpoint = "185.165.241.179:51820";
          persistentKeepalive = 25;
        }];
        
        autostart = false;  # Manual control
        table = "auto";
      };
    };
  };

  # Set your time zone.
  time.timeZone = "Europe/Amsterdam";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "nl_NL.UTF-8";
    LC_IDENTIFICATION = "nl_NL.UTF-8";
    LC_MEASUREMENT = "nl_NL.UTF-8";
    LC_MONETARY = "nl_NL.UTF-8";
    LC_NAME = "nl_NL.UTF-8";
    LC_NUMERIC = "nl_NL.UTF-8";
    LC_PAPER = "nl_NL.UTF-8";
    LC_TELEPHONE = "nl_NL.UTF-8";
    LC_TIME = "nl_NL.UTF-8";
  };

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  services = {
    k3s = {
      enable = false;
      role = "server";
      extraFlags = [
        # Disable traefik if you want your own ingress.
        # Then also change the nodeport services to clusterIP to isolate them.
        # This is simpler, it exposes all k3s services on the network, allows them
        # on the firewall, etc.
        "--disable=traefik"
        "--write-kubeconfig-mode=644"
      ];
    };

    samba = {
      enable = true;
      openFirewall = true;
      settings = {
        global = {
          "workgroup" = "WORKGROUP";
          "server string" = "nixos-nas";
          "netbios name" = "nixos";
          "security" = "user";
          "guest account" = "nobody";
          "map to guest" = "bad user";
        };
        "nas" = {
          "path" = cfg.nas.mountPoint;
          "browseable" = "yes";
          "read only" = "no";
          "guest ok" = "no"; # Safer: Requires a password
          "create mask" = "0644";
          "directory mask" = "0755";
          "force user" = "kasbuunk";
        };
      };
    };

    # Enable mDNS (Avahi) so your NAS shows up in sidebars automatically
    avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        userServices = true;
      };
    };
  };

  fileSystems.${cfg.nas.mountPoint} = {
    device = cfg.nas.deviceName;
    fsType = cfg.nas.format;
    options = [ "nofail" "users" ];
  };

  environment.etc."rancher/k3s/config.yaml".text = ''
    write-kubeconfig-mode: "0644"
    tls-san:
      - "192.168.1.76"
    cluster-init: true
    disable:
      - traefik
  '';

  # DNS.
  services.adguardhome = {
    enable = true;

    # Web interface and DNS ports
    port = cfg.services.adguard.httpPort;

    settings = {
      users = [{
        name = "admin";
        # Hash of the password - see 1password.
        password = "$2y$10$cLohIuXo0QgJp//b9PaEP.DBqGaMCwJIbLPN54ekPnljFz9FYYKoC";
      }];

      tls = {
        enabled = true;
        server_name = cfg.services.adguard.hostName;
        force_https = true;
        port_https = cfg.services.adguard.httpsPort;
        port_dns_over_tls = cfg.services.adguard.dnsOverTLSPort;
        certificate_path = config.sops.secrets.adguard-tls-cert.path;
        private_key_path = config.sops.secrets.adguard-tls-key.path;
      };


      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = cfg.services.adguard.dnsPort;

        # Upstream DNS servers (Cloudflare)
        bootstrap_dns = [ "1.1.1.1" "1.0.0.1" ];
        upstream_dns = [ "1.1.1.1" "1.0.0.1" ];

        # Local domain rewrites for your services
        rewrites = [
          {
            domain = cfg.services.gitea.hostName;
            answer = cfg.network.hostIp;
          }
          {
            domain = cfg.services.adguard.hostName;
            answer = cfg.network.hostIp;
          }
          {
            domain = cfg.services.jellyfin.hostName;
            answer = cfg.network.hostIp;
          }
          # Add more as you deploy services
        ];
      };
    };
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;
  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "us";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  security.pki.certificateFiles = [
    ./certs/ca.crt # Generated with openssl.
  ];

  security.sudo.extraRules = [{
    users = [ "kasbuunk" ];
    commands = [{
      command = "${pkgs.nixos-rebuild}/bin/nixos-rebuild";
      options = [ "NOPASSWD" ];
    }];
  }];

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  services.jellyfin = {
    enable = true;
    openFirewall = false; 
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.kasbuunk = {
    isNormalUser = true;
    description = "Kas Buunk";
    extraGroups = [ "networkmanager" "wheel" ];

    openssh.authorizedKeys.keys = [
      # Public key NixOS HomeLab in 1Password.
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINo3te96zjiEAQnLe30m/zyzMtII+R3S4lsmLFgsJoZa"

      # gitea public key in 1Password.
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL6GlOZP1Zt3MCD/NzWVPsuhoQSFil835qsQqzuktHmq"
    ];

    packages = with pkgs; [
      # Most packages are installed system-wide.
      kdePackages.kate
    ];

    # Default shell is fish.
    shell = pkgs.fish;
  };

  # Add this section to create the gitea system user
  users.users.gitea = {
    isSystemUser = true;
    group = "gitea";
    home = "/var/lib/gitea";
    createHome = true;
  };
  users.groups.gitea = { };

  users.users.adguardhome = {
    isSystemUser = true;
    group = "adguardhome";
  };
  users.groups.adguardhome = { };

  # Add Jellyfin to your user group so it can read your NAS files.
  users.users.jellyfin.extraGroups = [ "users" "kasbuunk" ];

  # Keep SSH available.
  powerManagement.enable = false;

  # Install firefox.
  programs.firefox.enable = true;

  # Enable Fish shell.
  programs.fish.enable = true;

  # Enable flakes for version control.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    _1password-gui
    age
    apacheHttpd
    git
    jq
    kubectl
    kubernetes-helm
    neovim
    openssl_oqs
    opentofu
    sops
    vim
    wget
    xclip
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    users.kasbuunk = { pkgs, ... }: {
      home = {
        stateVersion = "25.11";
        username = "kasbuunk";
        homeDirectory = "/home/kasbuunk";

        sessionVariables = {
          EDITOR = "nvim";
          KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
        };
        shellAliases = {
          "..." = "cd ../..";
          "...." = "cd ../../..";
          "....." = "cd ../../../..";
          "......" = "cd ../../../../..";
          "docker" = "podman";
          "cdn" = "cd ~/.config/nixos";
          "k" = "kubectl";
          "vim" = "nvim";
        };
      };

      programs = {
        alacritty = {
          enable = true;
        };

        fish = {
          enable = true;
          shellAliases = {
            zf = "z --pipe=fzf";
            build = "sudo nixos-rebuild switch --flake ~/.config/nixos";
          };
          plugins = with pkgs.fishPlugins; [
            { name = "fzf"; src = fzf-fish.src; } # better than built-in fzf keybinds
          ];
          shellInit = ''
          '';
        };
        fzf = {
          enable = true;
          enableFishIntegration = false; # use fzf-fish plugin instead
        };

        tmux = {
          enable = true;
          clock24 = true;
          customPaneNavigationAndResize = true;
          disableConfirmationPrompt = true;
          escapeTime = 0;
          keyMode = "vi";
          mouse = true;
          newSession = true;
          prefix = "c-a";
          extraConfig = ''
            # Make links clickable.
            set -ga terminal-features "*:hyperlinks"
    
            # Navigate windows.
            bind -n C-h select-pane -L
            bind -n C-j select-pane -D
            bind -n C-k select-pane -U
            bind -n C-l select-pane -R
    
            # Termguicolors.
            set -g default-terminal "$TERM"
            set -ag terminal-overrides ",$TERM:Tc"
            set-option -g default-shell /etc/profiles/per-user/kasbuunk/bin/fish
            set-option -g default-command /etc/profiles/per-user/kasbuunk/bin/fish
          '';
        };
      };
    };
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs = {
    # mtr.enable = true;
    # gnupg.agent = {
    #   enable = true;
    #   enableSSHSupport = true;
    # };
  };

  programs.ssh.startAgent = true;

  # List services that you want to enable:
  services = {
    gitea = {
      enable = true;

      database = {
        type = "postgres";
        host = "/run/postgresql"; # Unix socket
        name = "gitea";
        user = "gitea";
        # No password needed - uses peer authentication via unix socket
      };

      settings = {
        server = {
          DOMAIN = cfg.services.gitea.hostName;
          HTTP_ADDR = "0.0.0.0";
          HTTP_PORT = cfg.services.gitea.httpPort;
          ROOT_URL = "https://${cfg.services.gitea.hostName}:${toString cfg.services.gitea.httpPort}/";

          # Enable HTTPS
          PROTOCOL = "https";
          CERT_FILE = config.sops.secrets.gitea-tls-cert.path;
          KEY_FILE = config.sops.secrets.gitea-tls-key.path;

          START_SSH_SERVER = true;
          BUILTIN_SSH_SERVER_USER = "gitea";
          SSH_DOMAIN = cfg.services.gitea.hostName;
          SSH_PORT = cfg.services.gitea.sshPort;
        };

        service = {
          DISABLE_REGISTRATION = true; # Enable after creating admin
        };
      };
    };
    postgresql = {
      enable = true;
      package = pkgs.postgresql_16;

      # Listen on localhost only (services connect via unix socket or localhost)
      enableTCPIP = false;

      # Create databases and users for each service
      ensureDatabases = [ "gitea" ];

      ensureUsers = [
        {
          name = "gitea";
          ensureDBOwnership = true;
        }
      ];
    };

    # Optional: manual backup with postgresqlBackup service
    postgresqlBackup = {
      enable = true;
      databases = [ "gitea" ];
      location = "/var/backup/postgresql";
    };

    transmission = {
      enable = true;
      settings = {
        download-dir = "/home/kasbuunk/Downloads/torrent";
        rpc-bind-address = "0.0.0.0";
        rpc-whitelist-enabled = false;
        upload-limit = 0;
        upload-limit-enabled = true;
        ratio-limit = 0;
        ratio-limit-enabled = true;

        # Bind to VPN interface only.
        bind-address-ipv4 = "10.2.0.2";  # Your VPN IP
        peer-port-random-on-start = true;
      };
    };
  };

  systemd.services.transmission.after = [ "wg-quick-wg0.service" ];
  systemd.services.transmission.requires = [ "wg-quick-wg0.service" ];
  systemd.services.transmission.bindsTo = [ "wg-quick-wg0.service" ];


  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = true;
    };
    extraConfig = ''
      ClientAliveInterval 60
      ClientAliveCountMax 120
    '';
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

  systemd = {
    targets.sleep.enable = false;
    targets.suspend.enable = false;
    targets.hibernate.enable = false;
    targets.hybrid-sleep.enable = false;

    services.nixos-autoupdate = {
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      environment = {
        SSH_AUTH_SOCK = ""; # Disable SSH agent
      };
      path = [ pkgs.git pkgs.nix pkgs.nixos-rebuild pkgs.openssh ];
      script = ''
        git config --global --add safe.directory /home/kasbuunk/.config/nixos
        export GIT_SSH_COMMAND="ssh -i /root/.ssh/nixos-autoupdate -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes"
        cd /home/kasbuunk/.config/nixos/
        git pull origin main
        nix flake update
        git add flake.lock
        git -c commit.gpgsign=false commit -m "chore: auto-update flake.lock" || true
        git push origin main
        nixos-rebuild switch --flake .#nixos
      '';
    };

    timers.nixos-autoupdate = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        WakeSystem = true;
      };
    };

    services.gitea-admin-user = {
      wantedBy = [ "multi-user.target" ];
      after = [ "gitea.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "gitea";
      };
      script = ''
        while ! ${pkgs.curl}/bin/curl -sk https://localhost:${toString cfg.services.gitea.httpPort} > /dev/null; do
          sleep 1
        done
       
        ${config.services.gitea.package}/bin/gitea admin user create \
          --admin \
          --username admin \
          --password "$(cat ${config.sops.secrets.gitea-admin-password.path})" \
          --email admin@localhost \
          --must-change-password=false \
          -c ${config.services.gitea.stateDir}/custom/conf/app.ini \
          || true
      '';
    };
  };
}
