_:

{
  imports = [
    ../../modules/home/ssh
  ];

  programs.ssh.settings."*" = {
    IdentityFile = "~/.ssh/id_ed25519";
    IdentitiesOnly = true;
  };

  programs.ssh.settings."github.com" = {
    HostName = "github.com";
    User = "git";
  };
}
