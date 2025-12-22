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
    ssh = {
      port = 22;
    };
  };
}
