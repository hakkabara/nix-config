{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule (finalAttrs: {
  pname = "hackbrowserdata";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "moonD4rk";
    repo = "HackBrowserData";
    tag = "v${finalAttrs.version}";
    hash = "sha256-EJb3w0HwORXDxEFRu+9n398cQWG4RLgzcrfjfbiHKFg=";
  };

  vendorHash = "sha256-Ydv8S4X8MWEbbFrj8pMNFFlVcV+1SO1k9TS24p5BSms=";

  # Upstream uses modernc.org/sqlite (pure Go), so no CGO or sqlite buildInput
  # is needed. Deviates from dfir-nixos-plan §4; TASKS.md governs here.
  env.CGO_ENABLED = "0";

  ldflags = [
    "-s"
    "-w"
  ];

  meta = {
    description = "Extract and decrypt browser data (passwords, cookies, history, bookmarks) across platforms";
    homepage = "https://github.com/moonD4rk/HackBrowserData";
    changelog = "https://github.com/moonD4rk/HackBrowserData/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "hack-browser-data";
  };
})
