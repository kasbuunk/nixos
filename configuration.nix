# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/nvme0n1";
  boot.loader.grub.useOSProber = true;

  # Setup keyfile
  boot.initrd.secrets = {
    "/boot/crypto_keyfile.bin" = null;
  };

  boot.loader.grub.enableCryptodisk = true;

  boot.initrd.luks.devices."luks-bb4c75e7-5ece-4105-9647-6494eb386af4".keyFile = "/boot/crypto_keyfile.bin";
 
  networking = {
    hostName = "nixos"; # Define your hostname.

    # Enables wireless support via wpa_supplicant.
    # This is mutually exlusive from the networkmanager below (I think).
    # wireless.enable = true;  
  
    # Wake up server by sending a packet.
    interfaces.wlp11s0f3u4 = {
      ipv4.addresses = [{
        address = "192.168.1.76"; # Fixed in the router settings.
        prefixLength = 24;
      }];

      wakeOnLan.enable = true;
    };

    # Enable networking
    networkmanager.enable = true;

    defaultGateway = "192.168.1.1"; # Router ip.
    nameservers = [ "1.1.1.1" ]; # Cloudflare's DNS.

    # Configure network proxy if necessary
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # Open ports in the firewall.
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
        # DNS disabled until a solution is found.
        # 53
        # 3000
      ];
      allowedUDPPorts = [ 
        # DNS disabled until a solution is found.
        # 53
      ];
    };

    # Or disable the firewall altogether.
    # networking.firewall.enable = false;
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

  # DNS.
  services.adguardhome.enable = false; # Look into cloud-native solutions.

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
    ];

    packages = with pkgs; [
      kdePackages.kate
    #  thunderbird
    ];
  };

  # Keep SSH available.
  powerManagement.enable = false;

  # Install firefox.
  programs.firefox.enable = true;

  # Enable flakes for version control.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    _1password-gui
    git
    vim
    neovim
    xclip
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  
    users.kasbuunk = { pkgs, ... }: {
      home.stateVersion = "25.11";
      home.username = "kasbuunk";
      home.homeDirectory = "/home/kasbuunk";
      
      programs.tmux = {
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
          set-option -g default-shell /bin/zsh
          set-option -g default-command /bin/zsh
        '';
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

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
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
  system.stateVersion = "25.05"; # Did you read the comment?

  systemd = {
    targets.sleep.enable = false;
    targets.suspend.enable = false;
    targets.hibernate.enable = false;
    targets.hybrid-sleep.enable = false;
  };
}
