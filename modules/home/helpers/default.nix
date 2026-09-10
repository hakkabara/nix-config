{ ... }:

{
  # Shared user-level helper tools.
  #
  # Helper implementations belong here when they are reusable across
  # personal/workstation hosts and do not require system-level ownership.
  #
  # Secrets and host-specific values stay outside the helper itself.
  imports = [
    ./pihole
  ];
}
