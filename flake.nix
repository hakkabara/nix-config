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

    disko = {
      url = "github:nix-community/disko";
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
    nix-flatpak = {
      url = "github:gmodena/nix-flatpak";
    };

    # DankMaterialShell desktop shell.
    #
    # Use the official upstream DMS flake directly. DMS upstream itself
    # targets nixos-unstable, so reuse our already pinned unstable package
    # set instead of introducing a second independent Nixpkgs revision.

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
      disko,
      plasma-manager,
      wl-x11-clipsync,
      nix-flatpak,
      zellij-tools,
      ...
    }:
    let
      system = "x86_64-linux";

      # A second package set used only by modules that explicitly opt in.
      # `pkgs` remains the NixOS 26.05 stable package set.
      pkgsUnstable = nixpkgs-unstable.legacyPackages.${system};

      # Custom DFIR packages use the same pinned unstable revision they were
      # developed against. Unfree is allowed only in this dedicated package set.
      pkgsDfirBase = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      pkgsDfir = import ./packages { pkgsUnstable = pkgsDfirBase; };
    in
    {
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;

      # Expose custom packages for local per-package and batch builds.
      packages.${system} = pkgsDfir;

      nixosConfigurations = {
        work-vm = nixpkgs.lib.nixosSystem {
          inherit system;

          specialArgs = {
            inherit pkgsDfir pkgsUnstable wl-x11-clipsync;
          };

          modules = [
            ./hosts/work-vm

            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            sops-nix.nixosModules.sops

            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;

                # Preserve a colliding existing user file instead of failing
                # Home Manager activation. A later activation may replace
                # the previous automatic backup.
                backupFileExtension = "hm-backup";
                overwriteBackup = true;

                # Home Manager itself remains on release-26.05/stable.
                #
                # pkgsUnstable is exposed only for modules that explicitly
                # opt into fast-moving applications such as Niri/Zellij.
                extraSpecialArgs = {
                  inherit
                    pkgsUnstable
                    zellij-tools
                    ;
                };
              };
            }
          ];
        };

        surf-vm = nixpkgs.lib.nixosSystem {
          inherit system;

          specialArgs = {
            inherit wl-x11-clipsync;
          };

          modules = [
            ./hosts/surf-vm

            nix-flatpak.nixosModules.nix-flatpak
            home-manager.nixosModules.home-manager
            sops-nix.nixosModules.sops
            disko.nixosModules.disko

            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;

                # Preserve a colliding existing user file instead of failing
                # Home Manager activation. A later activation may replace
                # the previous automatic backup.
                backupFileExtension = "hm-backup";
                overwriteBackup = true;

                # Extra arguments available to Home Manager modules.
                #
                # Modules use stable `pkgs` unless they explicitly request
                # and select something from `pkgsUnstable`.
                extraSpecialArgs = {
                  inherit
                    plasma-manager
                    pkgsUnstable
                    zellij-tools
                    ;
                };
              };
            }
          ];
        };

      };
    };
}
