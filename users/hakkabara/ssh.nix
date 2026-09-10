_:

{
  imports = [
    ../../modules/home/ssh
  ];

  programs.ssh.settings."*" = {
    IdentityFile = "/run/secrets/ssh-system-key";
    IdentitiesOnly = true;
  };

  programs.ssh.settings."github.com" = {
    HostName = "github.com";
    User = "git";
  };
}
