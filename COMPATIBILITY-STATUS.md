# AutoScriptXray compatibility status

## Target platforms

- Debian 11
- Debian 12
- Debian 13
- Ubuntu 22.04
- Ubuntu 24.04
- Ubuntu 26.04

## Changes in this migration

- Project URLs migrated from `givps/AutoScriptXray` to `faisin/basry`.
- Project branch URLs migrated from `master` to `main`.
- Main installer validates `/etc/os-release` and accepts only the six target OS releases.
- Node.js bootstrap upgraded from Node.js 18 to Node.js 24 LTS.
- Removed unconditional full system upgrade from the WebSocket installer.
- UDP Custom now exits cleanly on non-amd64 architectures instead of downloading an incompatible binary.
- Fixed the syntax error in `ssh/xp.sh`.

## Still requires a dedicated follow-up

1. Replace bundled OpenVPN private-key material with per-VPS certificate generation.
2. Add an arm64 build of UDP Custom if ARM64 support is required.
3. Replace legacy `ifconfig`/`netstat`/`route` usage with `ip`/`ss`.
4. Consolidate firewall handling around nftables/iptables backend detection.
5. Stop modifying `/etc/resolv.conf` or disabling IPv6 by default.
6. Replace `rc.local` compatibility services with native systemd units.
7. Validate SSH configuration with `sshd -t` before restarting SSH.
8. Remove unpinned remote `master` dependencies belonging to third-party repositories only after reviewing each upstream project.

This package is a migration build, not a claim that every legacy module has been independently integration-tested on all six OS releases.


## Phase 1 (repository preparation)
- Canonical project source is configured as `https://raw.githubusercontent.com/faisin/basry/main`.
- `setup.sh` now detects supported Debian/Ubuntu releases through `/etc/os-release`.
- Base dependencies are installed before DNS/Cloudflare checks.
- Node.js 24 is used for the WebSocket proxy installer.
- Timezone defaults to UTC and can be overridden with `INSTALL_TZ`.
- All shell scripts pass `bash -n` syntax validation.
- Detailed firewall, DNS, OpenVPN credential regeneration, and legacy networking cleanup remain intentionally deferred to the next phase.
