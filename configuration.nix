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
    age.keyFile = "/var/lib/sops-nix/key.txt";

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

      # VPN Client.
      wireguard-config = {
        owner = "root";
        mode = "0400";
      };
      # VPN Server.
      wireguard-server-private-key = {
        owner = "root";
        mode = "0400";
      };
      restic-password = {
        owner = "root";
        mode = "0400";
      };
      grafana-admin-password = {
        owner = "grafana";
      };
      grafana-secret-key = {
        owner = "grafana";
      };
      ca-cert = {
        owner = "caddy";
      };
      ca-key = {
        owner = "caddy";
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

  networking = {
    hostName = "nixos"; # Define your hostname.

    # Enables wireless support via wpa_supplicant.
    # This is mutually exlusive from the networkmanager below (I think).
    # wireless.enable = true;  

    # Enable networking
    networkmanager.enable = true;
    networkmanager.ensureProfiles.profiles = {
      "lan-connection" = {
        connection = {
          id = "lan-connection";
          type = "ethernet";
          interface-name = cfg.network.lanInterface;
        };
        ipv4 = {
          method = "manual";
          address1 = "${cfg.network.hostIp}/24,${cfg.network.gateway}";
          dns = cfg.network.dns;
        };
      };
    };

    nameservers = [ cfg.network.dns ]; # Cloudflare's DNS.

    # Configure network proxy if necessary
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # Open ports in the firewall.
    firewall = {
      enable = true;

      # Global ports (accessible from all interfaces).
      allowedUDPPorts = [
        cfg.network.vpnPort # WireGuard server - must be accessible from internet.
      ];

      # LAN-only access.
      interfaces.${cfg.network.lanInterface} = {
        allowedTCPPorts = [
          cfg.services.caddy.httpPort # Reverse proxy for all services.
          cfg.services.caddy.httpsPort
	  # cfg.services.adguard.httpPort
	  cfg.services.adguard.httpsPort
          cfg.services.adguard.dnsPort # DNS.
          cfg.services.adguard.dnsOverTLSPort
          cfg.services.gitea.sshPort # Git SSH.
          cfg.nas.tcp1 # Samba.
          cfg.nas.tcp2
        ];
        allowedUDPPorts = [
          cfg.services.adguard.dnsPort # DNS.
          cfg.nas.udp1 # Samba.
          cfg.nas.udp2
        ];
      };

      # VPN-only access
      interfaces.${cfg.network.vpnInterface} = {
        allowedTCPPorts = [
          cfg.services.ssh.port # SSH only via VPN.
          cfg.services.caddy.httpPort # Access services via VPN.
          cfg.services.caddy.httpsPort
          cfg.services.adguard.dnsPort # DNS.
          cfg.services.adguard.dnsOverTLSPort
          cfg.services.gitea.sshPort # Git SSH.
          cfg.nas.tcp1 # Samba.
          cfg.nas.tcp2
        ];
        allowedUDPPorts = [
          cfg.services.adguard.dnsPort # DNS
          cfg.nas.udp1 # Samba
          cfg.nas.udp2
        ];
      };
    };

    wireguard.interfaces.${cfg.network.vpnInterface} = {
      ips = [ "10.0.0.1/24" ];
      listenPort = cfg.network.vpnPort;

      privateKeyFile = config.sops.secrets.wireguard-server-private-key.path;

      peers = [
        {
	  name = "phone";
	  publicKey = "LP8gDDyNvldcc/lVkuP8pjEMGTx4DRGeG8FHujrJ8Dw=";
	  allowedIPs = [ "10.0.0.2/32" ];
	}
        {
	  name = "laptop";
	  publicKey = "mMIzeWJbhUKCAybziDFueRJ/i9qPQYzW/UZORdX2zzc=";
	  allowedIPs = [ "10.0.0.3/32" ];
	}
      ];
    };
  };

  # VPN namespace configuration.
  vpnNamespaces.wg = {
    enable = true;
    wireguardConfigFile = config.sops.secrets.wireguard-config.path;
    accessibleFrom = [ 
      "192.168.1.0/24" # LAN.
      "10.0.0.0/24"
    ]; # LAN can access services.
    portMappings = [{
      from = cfg.services.transmission.httpPort;
      to = cfg.services.transmission.httpPort; # Transmission web UI.
    }];
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
    caddy = {
      enable = true;
      globalConfig = ''
        auto_https off
      '';
      virtualHosts = {
        # Gitea.
	"https://${cfg.services.gitea.hostName}" = {
	  extraConfig = ''
	    tls ${config.sops.secrets."ca-cert".path} ${config.sops.secrets."ca-key".path}
	    reverse_proxy localhost:${toString cfg.services.gitea.httpPort} {
	      header_up Host {host}
              header_up X-Real-IP {remote_host}
	    }
	  '';
	};
        # Jellyfin.
	"https://${cfg.services.jellyfin.hostName}" = {
	  extraConfig = ''
	    tls ${config.sops.secrets."ca-cert".path} ${config.sops.secrets."ca-key".path}
	    reverse_proxy localhost:${toString cfg.services.jellyfin.httpPort} {
	      header_up Host {host}
              header_up X-Real-IP {remote_host}
	    }
	  '';
	};
        # Immich.
	"https://${cfg.services.immich.hostName}" = {
	  extraConfig = ''
	    tls ${config.sops.secrets."ca-cert".path} ${config.sops.secrets."ca-key".path}
	    reverse_proxy localhost:${toString cfg.services.immich.httpPort} {
	      header_up Host {host}
              header_up X-Real-IP {remote_host}
	    }
	  '';
	};
        # AdGuard.
	"https://${cfg.services.adguard.hostName}" = {
	  extraConfig = ''
	    tls ${config.sops.secrets."ca-cert".path} ${config.sops.secrets."ca-key".path}
	    reverse_proxy localhost:${toString cfg.services.adguard.httpPort} {
	      header_up Host {host}
              header_up X-Real-IP {remote_host}
	    }
	  '';
	};
        # Grafana.
	"https://${cfg.services.grafana.hostName}" = {
	  extraConfig = ''
	    tls ${config.sops.secrets."ca-cert".path} ${config.sops.secrets."ca-key".path}
	    reverse_proxy localhost:${toString cfg.services.grafana.httpPort} {
	      header_up Host {host}
              header_up X-Real-IP {remote_host}
	    }
	  '';
	};
        # Transmission.
	"https://${cfg.services.transmission.hostName}" = {
	  extraConfig = ''
	    tls ${config.sops.secrets."ca-cert".path} ${config.sops.secrets."ca-key".path}
	    reverse_proxy ${cfg.network.vpnNamespaceIp}:${toString cfg.services.transmission.httpPort} {
	      header_up Host {host}
              header_up X-Real-IP {remote_host}
	    }
	  '';
	};
      };
    };

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

    # Home photos and videos.
    immich = {
      enable = true;
      port = cfg.services.immich.httpPort;
      # Use your NAS as the storage location
      mediaLocation = cfg.services.immich.mediaLocation;
      host = "0.0.0.0";
    };

    # Loki - log storage.
    loki = {
      enable = true;
      dataDir = cfg.services.loki.dataDir;
      configuration = {
        auth_enabled = false; # Secure access via Grafana.
        server = {
	  http_listen_address = "127.0.0.1";
	  http_listen_port = cfg.services.loki.httpPort;
	  grpc_listen_address = "127.0.0.1";
	};

        common = {
          instance_addr = "127.0.0.1";
          path_prefix = cfg.services.loki.dataDir;
          storage.filesystem = {
            chunks_directory = "${cfg.services.loki.dataDir}/chunks";
            rules_directory = "${cfg.services.loki.dataDir}/rules";
          };
          replication_factor = 1;
          ring.kvstore.store = "inmemory";
        };

        schema_config.configs = [{
          from = "2024-01-01";
          store = "tsdb";  # Modern storage backend
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }];

        storage_config = {
	  filesystem.directory = "${cfg.services.loki.dataDir}/chunks";
	  tsdb_shipper = {
	    active_index_directory = "${cfg.services.loki.dataDir}/index";
	    cache_location = "${cfg.services.loki.dataDir}/index_cache";
	  };
        };

        compactor = {
          working_directory = "${cfg.services.loki.dataDir}/compactor";
          retention_enabled = true;
          retention_delete_delay = "2h";
	  compaction_interval = "10m";
	  delete_request_store = "filesystem";
        };

        limits_config = {
          retention_period = "720h"; # 30 days.
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";

          max_streams_per_user = 10000;
	  max_global_streams_per_user = 10000;
        };
      };
    };

    # Promtail - ships journald logs to Loki.
    promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 9080;
          grpc_listen_port = 0;
        };

        positions.filename = "/var/lib/promtail/positions.yaml";

        clients = [{
          url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}/loki/api/v1/push";
        }];

        scrape_configs = [{
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = config.networking.hostName;
            };
          };
	  pipeline_stages = [
            # Drop noisy units entirely
            {
              match = {
		selector = "{unit=~\"session-.*\\\\.scope\"}";
                action = "drop";
              };
            }
            # Extract log level
            {
              regex = {
                expression = "^(?P<level>DEBUG|INFO|WARN|ERROR|FATAL)";
              };
            }
            {
              labels = {
                level = "";
              };
            }
          ];
          relabel_configs = [
            {
              source_labels = ["__journal__systemd_unit"];
              target_label = "unit";
            }
          ];
        }];
      };
    };
  
    # Grafana - visualization
    grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "0.0.0.0"; # Expose to LAN.
          http_port = cfg.services.grafana.httpPort;
	  domain = cfg.services.grafana.hostName;
	  root_url = "https://${cfg.services.grafana.hostName}/";
	  serve_from_sub_path = true;
          # Force login.
          enforce_domain = true;
        };

	security = {
	  admin_user = "admin";
	  admin_password = "$__file{${config.sops.secrets.grafana-admin-password.path}}";
	  secret_key = "$__file{${config.sops.secrets.grafana-secret-key.path}}";
	};
	"auth.anonymous" = {
	  enabled = false; # No anonymous access.
	};

        analytics = {
          reporting_enabled = false;
          check_for_updates = false;
          check_for_plugin_updates = false;
          feedback_links_enabled = false;
        };
      };
      
      provision = {
        enable = true;
        datasources.settings.datasources = [{
          name = "Loki";
          type = "loki";
          access = "proxy";
          url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
          isDefault = true;
        }];
      };
    };

    jellyfin = {
      enable = true;
      openFirewall = false; 
    };

    # DNS.
    adguardhome = {
      enable = true;

      # Web interface and DNS ports
      host = "0.0.0.0"; # Both local and LAN.
      port = cfg.services.adguard.httpPort;

      settings = {
        users = [{
          name = "admin";
          # bcrypt hash of the password - see 1password.
          # Generate new one with: htpasswd -B -n -b admin "my-password"
          password = "$2y$10$cLohIuXo0QgJp//b9PaEP.DBqGaMCwJIbLPN54ekPnljFz9FYYKoC";
        }];

        dns = {
          bind_hosts = [ cfg.network.hostIp "127.0.0.1" ];
          port = cfg.services.adguard.dnsPort;

          # Upstream DNS servers (Cloudflare).
          bootstrap_dns = [ "1.1.1.1" "1.0.0.1" ];
          upstream_dns = [ 
            "1.1.1.1" # Route through the gateway.
            "1.0.0.1" 
          ];

          # Force upstream queries to bypass VPN by binding to LAN interface.
          upstream_dns_file = "";

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

    # Git server.
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

          PROTOCOL = "http";
	  # HTTPS is disabled in favour of using caddy.
          # CERT_FILE = config.sops.secrets.gitea-tls-cert.path;
          # KEY_FILE = config.sops.secrets.gitea-tls-key.path;

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

    # Database.
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
      location = "${cfg.nas.mountPoint}/data/postgres-backup"; # Store on NAS.
    };

    restic.backups.local = {
      user = "root"; # Default.
      initialize = true;
      paths = cfg.backup.paths;
      repository = "${cfg.backup.mountPoint}/restic";
      passwordFile = config.sops.secrets.restic-password.path;

      # Run this daily at 3:00 AM (one hour after your cloud job).
      timerConfig = {
        OnCalendar = "03:00";
        RandomizedDelaySec = "30min";
        Persistent = true;
      };

      # Your custom retention policy: keep plenty of recent, fewer old.
      pruneOpts = [
        "--keep-daily 7"    # Last 7 days
        "--keep-weekly 4"   # Last 4 weeks
        "--keep-monthly 6"  # Last 6 months
        "--keep-yearly 5"   # Last 2 years
      ];
    };

    transmission = {
      enable = true;
      settings = {
        download-dir = "${cfg.nas.mountPoint}/data/torrents";
        incomplete-dir = "${cfg.nas.mountPoint}/data/torrents/.incomplete";
        incomplete-dir-enabled = true;

        # Network/Access settings.
        # Bind to 0.0.0.0 so it listens to requests coming from the "Port Mapping"
        rpc-bind-address = "0.0.0.0";
        # Allow access from the LAN (192.168.*.*)
        rpc-whitelist = "127.0.0.1,192.168.*.*";
        rpc-whitelist-enabled = true;

        # Permissions (Crucial!)
        # umask 2 (decimal) results in 775/664 permissions, allowing group members to write.
        umask = 2;

        # Possibly this excludes from seeders.
        # upload-limit = 0;
        # upload-limit-enabled = true;
        # ratio-limit = 0.1;
        # ratio-limit-enabled = true;

        peer-port-random-on-start = true;
      };
    };
  };

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

  fileSystems.${cfg.nas.mountPoint} = {
    device = cfg.nas.deviceName;
    fsType = cfg.nas.format;
    options = [ "nofail" "users" ];
  };

  fileSystems.${cfg.backup.mountPoint} = {
    device = cfg.backup.deviceName;
    fsType = cfg.backup.format;
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

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;
  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Configure console keymap.
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

  # Permission glue to let me and jellyfin access the transmission group.
  users.groups.transmission.members = [ "kasbuunk" "jellyfin" ];

  # Keep SSH available.
  powerManagement.enable = false;

  # Install firefox.
  programs.firefox.enable = true;

  # Enable Fish shell.
  programs.fish.enable = true;

  programs.ssh.startAgent = true;

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
    e2fsprogs
    git
    htop
    iotop
    jq
    kubectl
    kubernetes-helm
    neovim
    nixfmt-rfc-style
    openssl_oqs
    opentofu
    parted
    ripgrep
    rustup
    sops
    sysstat
    vim
    wget
    wireguard-tools
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
          # Check if we are in an SSH session (Remote)
          if test -n "$SSH_CONNECTION"
              # We are remote: Do nothing. Use the socket forwarded by SSH.
              echo "Remote session detected. Using forwarded SSH agent."
          else
              # We are local (GUI/Console): Point to 1Password
              # (Ensure you enabled the SSH Agent in 1Password Developer Settings)
              if test -S ~/.1password/agent.sock
                  set -x SSH_AUTH_SOCK ~/.1password/agent.sock
              end
          end
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

    tmpfiles.rules = [
      "d ${cfg.services.loki.dataDir} 0700 loki loki -"
      "d /var/lib/promtail 0700 promtail promtail -"
      "d ${cfg.nas.mountPoint}/data/torrents 0775 transmission transmission -"
      "d ${cfg.nas.mountPoint}/data/torrents/.incomplete 0775 transmission transmission -"
    ];

    services.transmission = {
      vpnConfinement = {
        enable = true;
        vpnNamespace = "wg";
      };

      serviceConfig = {
        BindPaths = [
          "/mnt/nas/data/torrents"
        ];
      };
    };

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
        # 1. Setup Git
        git config --global --add safe.directory /home/kasbuunk/.config/nixos
        export GIT_SSH_COMMAND="ssh -i /root/.ssh/nixos-autoupdate -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes"
        cd /home/kasbuunk/.config/nixos/
        git pull origin main

        # 2. Update Flake Lockfile
        nix flake update

        # 3. SAFETY CHECK: Dry Run
        # If this fails, the script stops here and doesn't break the system.
        echo "Running dry-activate..."
        nixos-rebuild dry-activate --flake .#nixos || exit 1

        # 4. Commit and Push.
        git add flake.lock
        # Only commit if there are changes
        if ! git diff --cached --quiet; then
          git -c commit.gpgsign=false commit -m "chore: auto-update flake.lock"
          git push origin main
        fi

        # 5. Apply Changes
        echo "Switching to new configuration..."
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
