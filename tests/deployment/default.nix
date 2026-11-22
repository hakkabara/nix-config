# DeployVM tooling without network access:
#   - deploy-ssh-key creates the local key and known_hosts
#   - deploy-repo-sync clones and follows a repository over SSH with it
#   - deploy-cache-pin-inputs rotates input GC roots and protects them
#   - nix flake archive --json yields the paths deploy-build pins
#
# Run: nix build .#vmTests.deployment -L
{
  name = "deployment-tooling";

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [
        ../../modules/nixos/tools/deployment/default.nix
        ../../modules/nixos/nix/cache-retention.nix
      ];

      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];

      users.users = {
        mko = {
          isNormalUser = true;
          group = "users";
        };

        git = {
          isNormalUser = true;
          group = "users";
        };
      };

      services.openssh.enable = true;

      hakkabara = {
        nix.cacheRetention.enable = true;

        tools.deployment = {
          enable = true;

          repositories.nix-config = {
            url = "ssh://git@localhost/home/git/nix-config.git";
            branch = "main";
          };

          sshKey = {
            enable = true;
            knownHostNames = [ "localhost" ];
          };
        };
      };

      environment.systemPackages = [
        pkgs.git
        pkgs.jq
      ];
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("sshd.service")

    with subtest("deploy-ssh-key creates key and known_hosts"):
        machine.succeed("systemctl start deploy-ssh-key.service")
        machine.succeed("test -s /persist/deployment/ssh/id_ed25519")
        machine.succeed("test $(stat -c %U:%a /persist/deployment/ssh/id_ed25519) = mko:600")
        machine.succeed("grep -q '^localhost ssh-ed25519 ' /persist/deployment/ssh/known_hosts")
        key1 = machine.succeed("cat /persist/deployment/ssh/id_ed25519.pub")
        machine.succeed("systemctl restart deploy-ssh-key.service")
        assert key1 == machine.succeed("cat /persist/deployment/ssh/id_ed25519.pub"), "key regenerated"
        machine.succeed("grep -q '^Host localhost$' /persist/deployment/ssh/config")

    with subtest("deploy-ssh-key repairs a partial key"):
        machine.succeed("rm /persist/deployment/ssh/id_ed25519.pub")
        machine.succeed("systemctl restart deploy-ssh-key.service")
        assert key1.split()[:2] == machine.succeed("cat /persist/deployment/ssh/id_ed25519.pub").split()[:2], "pub not restored"
        machine.succeed(": > /persist/deployment/ssh/id_ed25519")
        machine.succeed("systemctl restart deploy-ssh-key.service")
        machine.succeed("test -s /persist/deployment/ssh/id_ed25519")
        key1 = machine.succeed("cat /persist/deployment/ssh/id_ed25519.pub")

    with subtest("git server accepts only the deploy key"):
        machine.succeed(
            "install -d -m 700 -o git -g users /home/git/.ssh",
            "install -m 600 -o git -g users /persist/deployment/ssh/id_ed25519.pub /home/git/.ssh/authorized_keys",
            "su git -c 'git init -q --bare -b main /home/git/nix-config.git'",
            "su git -c 'git clone -q /home/git/nix-config.git /tmp/work'",
            "su git -c 'cd /tmp/work && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m one && git push -q origin main'",
        )

    with subtest("deploy-repo-sync clones over SSH"):
        out = machine.succeed("su mko -c deploy-repo-sync")
        assert "PASS: all managed repositories synchronized." in out, out
        machine.succeed("test -d /persist/deployment/repos/nix-config/.git")

    with subtest("deploy-repo-sync fetches new commits"):
        machine.succeed(
            "su git -c 'cd /tmp/work && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m two && git push -q origin main'"
        )
        machine.succeed("su mko -c deploy-repo-sync")
        head = machine.succeed("su mko -c 'git -C /persist/deployment/repos/nix-config log -1 --format=%s'").strip()
        assert head == "two", head

    with subtest("deploy-repo-sync refuses a dirty checkout"):
        machine.succeed("su mko -c 'touch /persist/deployment/repos/nix-config/x && cd /persist/deployment/repos/nix-config && git add x'")
        machine.fail("su mko -c deploy-repo-sync")
        machine.succeed("su mko -c 'cd /persist/deployment/repos/nix-config && git rm -q --cached x && rm x'")

    with subtest("unknown host key is rejected"):
        machine.succeed("cp /persist/deployment/ssh/known_hosts /tmp/known_hosts.bak")
        machine.succeed("sed -i 's/ssh-ed25519 .*/ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl/' /persist/deployment/ssh/known_hosts")
        machine.fail("su mko -c deploy-repo-sync")
        machine.succeed("cp /tmp/known_hosts.bak /persist/deployment/ssh/known_hosts")

    with subtest("flake archive lists every input path"):
        machine.succeed(
            "mkdir -p /tmp/dep /tmp/top",
            "echo '{ outputs = _: { v = 1; }; }' > /tmp/dep/flake.nix",
            "cd /tmp/dep && git init -q && git add . && git -c user.name=t -c user.email=t@t commit -q -m dep",
            "echo '{ inputs.dep.url = \"git+file:///tmp/dep\"; outputs = { dep, ... }: { v = dep.v; }; }' > /tmp/top/flake.nix",
            "cd /tmp/top && git init -q && git add . && nix flake lock && git add . && git -c user.name=t -c user.email=t@t commit -q -m top",
        )
        paths = machine.succeed(
            "cd /tmp/top && nix flake archive --no-update-lock-file --json | jq -r 'def paths: .path, (.inputs // {} | .[] | paths); paths' | sort -u"
        ).split()
        assert len(paths) == 2, paths

    with subtest("deploy-cache-pin-inputs pins and rotates"):
        machine.fail(f"su mko -c 'deploy-cache-pin-inputs work-vm {paths[0]}'")
        machine.fail("deploy-cache-pin-inputs work-vm /etc/passwd")
        machine.fail(f"deploy-cache-pin-inputs Bad_Host {paths[0]}")
        machine.succeed(f"deploy-cache-pin-inputs work-vm {' '.join(paths)}")
        root = "/nix/var/nix/gcroots/hakkabara/work-vm"
        for p in paths:
            machine.succeed(f"test $(readlink -f {root}/inputs/$(basename {p})) = {p}")
        machine.succeed("nix-collect-garbage >/dev/null")
        for p in paths:
            machine.succeed(f"test -e {p}")

        machine.succeed(f"deploy-cache-pin-inputs work-vm {paths[0]}")
        machine.succeed(f"test $(ls {root}/inputs | wc -l) = 1")
        machine.succeed(f"test $(ls {root}/inputs-previous | wc -l) = 2")
        machine.succeed(f"test ! -e {root}/.inputs.*.tmp")
  '';
}
