{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  libgit2,
  libssh2,
  openssl,
  zlib,
  openssh,
  makeWrapper,
  installShellFiles,
  versionCheckHook,
  nix-update-script,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "sshelf";
  version = "0.13.1";

  src = fetchFromGitHub {
    owner = "max-rh";
    repo = "sshelf";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Q5IMxul7qVZ35pjub0kRA1+xqzfwugViti9ffXJqUkM=";
  };

  cargoHash = "sha256-NJSz7UKhFugI1ZehpZ5fQ28whfe2mGQi/EK51kWbGbc=";

  # The upstream vault tests are not reliable when the Cargo
  # test harness runs tests concurrently. Keep the full test
  # suite enabled, but use buildRustPackage's native serial mode.
  dontUseCargoParallelTests = true;

  # ssh2-config pulls in git2/libgit2. Use nixpkgs' libgit2 instead
  # of building the vendored C copy.
  env.LIBGIT2_NO_VENDOR = "1";

  nativeBuildInputs = [
    pkg-config
    installShellFiles
    makeWrapper
  ];

  buildInputs = [
    libgit2
    libssh2
    openssl
    zlib
  ];

  # Upstream exposes --version through clap.
  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  # Upstream generates static completions and the roff man page itself.
  postInstall = ''
    installShellCompletion --cmd sshelf \
      --bash <($out/bin/sshelf completions bash) \
      --zsh <($out/bin/sshelf completions zsh) \
      --fish <($out/bin/sshelf completions fish)

    $out/bin/sshelf man > sshelf.1
    installManPage sshelf.1
  '';

  # sshelf intentionally execs the real OpenSSH client when connecting.
  # Make that runtime dependency explicit instead of relying on the host PATH.
  postFixup = ''
    wrapProgram $out/bin/sshelf \
      --prefix PATH : ${lib.makeBinPath [ openssh ]}
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Fast terminal UI for SSH hosts with fuzzy search, SFTP transfer and port forwarding";
    homepage = "https://github.com/max-rh/sshelf";
    changelog = "https://github.com/max-rh/sshelf/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      asl20
      mit
    ];
    platforms = lib.platforms.unix;
    mainProgram = "sshelf";
  };
})
