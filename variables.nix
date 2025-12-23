{
  network = {
    hostIp = "192.168.1.76";
    gateway = "192.168.1.1";
    dns = "1.1.1.1";
    interface = "wlp11s0f3u4";
  };

  services = {
    adguard = {
      hostName = "dns.home";
      httpPort = 3001;
      httpsPort = 3002;
      dnsPort = 53;
      dnsOverTLSPort = 853;
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
      port = 2283;
      mediaLocation = "/mnt/nas/data/photos";
    };
    ssh = {
      port = 22;
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
