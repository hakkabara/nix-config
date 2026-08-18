# Upstream provenance

- Repository: `https://github.com/lnav-xenserver-logs/lnav_xenserver_logs`
- Commit: `b3ffe261557669f9d17d438c0029f3d1bda9d997`
- License: BSD-style (see `LICENSE`)

Included file:

- `citrix_hypervisor.json`

Compatibility modification for SurfVM:

- Removed obsolete `module-format` properties because lnav 0.14 removed module
  format support. The regex/sample definitions themselves remain intact and are
  covered by the repository regression test.
