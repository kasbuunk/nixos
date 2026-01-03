{
  network = {
    hostIp = "192.168.1.76";
    gateway = "192.168.1.1";
    dns = "1.1.1.1";
    lanInterface = "wlp11s0f3u4";
    vpnServerInterface = "wgserver";
    vpnNamespaceIp = "192.168.15.1";
    vpnPort = 51820;
  };

  services = {
    adguard = {
      hostName = "dns.home";
      httpPort = 3001;
      httpsPort = 3002;
      dnsPort = 53;
      dnsOverTLSPort = 853;
    };
    caddy = {
      httpPort = 80;
      httpsPort = 443;
    };
    gitea = {
      hostName = "git.home";
      httpPort = 30300;
      sshPort = 30222;
    };
    jellyfin = {
      hostName = "media.home";
      httpPort = 8096;
    };
    immich = {
      hostName = "photos.home";
      httpPort = 2283;
      mediaLocation = "/mnt/nas/data/photos";
    };
    ssh = {
      port = 22;
    };
    loki = {
      dataDir = "/mnt/nas/data/log";
      httpPort = 3100;
    };
    mimir = {
      dataDir = "/var/lib/mimir/data";
      httpPort = 9009;
      grpcPort = 9096;
    };
    grafana = {
      hostName = "grafana.home";
      httpPort = 3000;
    };
    transmission = {
      hostName = "transmission.home";
      httpPort = 9091;
    };
    homeassistant = {
      hostName = "home.home";
      httpPort = 8123;
      configDir = "/mnt/nas/data/config/home-assistant";
    };
    crowdsec = {
      httpPort = 8080;
      metricsPort = 6060;
    };
    suricata = {
      dataDir = "/var/lib/suricata";
    };
  };

  nas = {
    # Configure during naming, formatting and partitioning.
    mountPoint = "/mnt/nas";
    format = "ext4";
    deviceName = "/dev/disk/by-label/nasdata";
    tcp1 = 445;
    tcp2 = 139;
    udp1 = 137;
    udp2 = 138;
  };
  backup = {
    mountPoint = "/mnt/backup";
    format = "ext4";
    deviceName = "/dev/disk/by-label/nasdata-backup";
    paths = [ "/mnt/nas/data" ]; # Directories to back up.
  };
}
