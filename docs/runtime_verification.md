# Runtime Verification

Last checked: 2026-06-20.

## Host

```text
macOS: 26.5
Architecture: arm64
```

## Git Baseline

```text
Branch: main
Remote: origin/main
Baseline before this note: bcf8ff6 Create Apple container ROS 2 desktop scaffold
```

## Completed Checks

```bash
bash -n scripts/attach_container.sh scripts/build_container.sh scripts/container-entrypoint.sh scripts/preflight.sh scripts/start_container.sh scripts/stop_container.sh
```

The simulator JavaScript compiles, and all 32 sensor/compression/network combinations produce finite metrics.

## Blocker

The Apple `container` CLI is not installed on this host. The official signed installer package was downloaded from the Apple GitHub release:

```text
Release: apple/container 1.0.0
Asset: container-1.0.0-installer-signed.pkg
Size: 89150563 bytes
SHA-256: 13f45f26da94c354adcbefe1e8f7631e7f126e93c5d4dd6a5a538aa66b4f479d
```

The downloaded file size and SHA-256 match the GitHub release metadata, but local macOS package validation failed:

```text
pkgutil --check-signature /private/tmp/container-1.0.0-installer-signed.pkg
Package "container-1.0.0-installer-signed.pkg":
   Status: invalid signature

spctl -a -vv -t install /private/tmp/container-1.0.0-installer-signed.pkg
/private/tmp/container-1.0.0-installer-signed.pkg: internal error in Code Signing subsystem
```

Because the signed installer does not validate locally, it was not installed.

## Next Safe Step

Do not run the installer until the package signature validates. Recheck the latest Apple `container` release or use an Apple-documented alternative install path, then rerun:

```bash
./scripts/preflight.sh
./scripts/build_container.sh
./scripts/start_container.sh
```
