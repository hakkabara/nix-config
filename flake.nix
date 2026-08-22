{
  description = "Hakkabara NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Opt-in package source for individual fast-moving applications.
    #
    # The system remains on NixOS 26.05 stable. Packages from this
    # input must be selected explicitly through pkgsUnstable.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    wl-x11-clipsync = {
      url = "github:Kyubai/wl-x11-clipsync";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Zellij scratchpads and companion CLI.
    #
    # The concrete upstream revision is pinned in flake.lock.
    zellij-tools = {
      url = "github:b0o/zellij-tools";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      sops-nix,
      plasma-manager,
      wl-x11-clipsync,
      zellij-tools,
      ...
    }:
    let
      system = "x86_64-linux";

      # A second package set used only by modules that explicitly opt in.
      # `pkgs` remains the NixOS 26.05 stable package set.
      pkgsUnstable = nixpkgs-unstable.legacyPackages.${system};
    in
    {
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;

      nixosConfigurations.surf-vm = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit wl-x11-clipsync;
        };

        modules = [
          ./hosts/surf-vm

          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops

          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;

              # Extra arguments available to Home Manager modules.
              #
              # Modules use stable `pkgs` unless they explicitly request
              # and select something from `pkgsUnstable`.
              extraSpecialArgs = {
                inherit plasma-manager pkgsUnstable zellij-tools;
              };
            };
          }
        ];
      };
    };
}
