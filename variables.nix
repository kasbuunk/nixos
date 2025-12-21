{
  network = {
    hostIp = "192.168.1.76";
    gateway = "192.168.1.1";
    dns = "1.1.1.1";
    interface = "wlp11s0f3u4";
  };

  services = {
    gitea = {
      httpPort = 30300;
      sshPort = 30222;
    };
    ssh = {
      port = 22;
    };
  };
}
