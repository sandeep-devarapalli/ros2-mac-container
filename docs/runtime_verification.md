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
Baseline before source-build verification: 10c86ca Document container runtime verification blocker
```

## Completed Checks

```bash
bash -n scripts/attach_container.sh scripts/build_container.sh scripts/container-entrypoint.sh scripts/preflight.sh scripts/start_container.sh scripts/stop_container.sh
```

The simulator JavaScript compiles, and all 32 sensor/compression/network combinations produce finite metrics.

## Installer Signature Check

The official signed installer package was downloaded from the Apple GitHub release:

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

## Source Build Verification

Apple `container` 1.0.0 was built from source instead:

```text
Source: https://github.com/apple/container
Tag: 1.0.0
Commit: ee848e3 Add backward compat for ContainerConfig cpuOverhead
Xcode: 26.5
Swift: 6.3.2
```

The source tree was cloned under `/private/tmp/apple-container-src` to avoid macOS Desktop/Documents virtualization permission issues. The release build completed and produced:

```text
/private/tmp/apple-container-src/bin/container
/private/tmp/apple-container-src/bin/container-apiserver
container CLI version 1.0.0 (build: release, commit: ee848e3)
```

Unit tests passed:

```text
XCTest: 94 tests, 0 failures
Swift Testing: 544 tests in 69 suites passed
```

The upstream integration target initially failed while downloading the Kata kernel:

```text
Installing kernel...
Error: HTTPClientError.connectTimeout
```

The same kernel archive was then downloaded directly and installed from the local tarball:

```text
Archive: kata-static-3.28.0-arm64.tar.zst
SHA-256: f63d54507d1f18635d94475077e4c2330de4d8e05cedf25f7c38f063b0e66a91
Kernel: opt/kata/share/kata-containers/vmlinux-6.18.15-186
```

Apple `container` runtime smoke test passed:

```bash
PATH=/private/tmp/apple-container-src/bin:$PATH container run --rm alpine uname -a
```

```text
Linux a47b421b-a51e-4914-aca8-938008f761b0 6.18.15 #1 SMP Tue Mar 17 01:36:53 UTC 2026 aarch64 Linux
```

Global install was not completed because `make install` requires an interactive `sudo` password. Until the user installs the signed package or completes `make install`, use:

```bash
export PATH=/private/tmp/apple-container-src/bin:$PATH
```

## ROS 2 Image Verification

With the source-built CLI on `PATH`, repo preflight passed:

```bash
PATH=/private/tmp/apple-container-src/bin:$PATH ./scripts/preflight.sh
```

The ROS 2 desktop image built successfully:

```bash
PATH=/private/tmp/apple-container-src/bin:$PATH ./scripts/build_container.sh
```

```text
ros2-mac-container:latest
```

The container launched successfully:

```bash
PATH=/private/tmp/apple-container-src/bin:$PATH ./scripts/start_container.sh
```

```text
ros2_mac_container
RDP: 127.0.0.1:3389
ROS bridge/WebSocket: 127.0.0.1:8765
Zenoh route: 127.0.0.1:7447
ROS 2 socket buffer cap: 16777216 bytes
```

Runtime state:

```text
ID                  IMAGE                       OS     ARCH   STATE    IP
ros2_mac_container  ros2-mac-container:latest   linux  arm64  running  192.168.64.5/24
```

Host port listeners were verified:

```text
127.0.0.1:3389  LISTEN
127.0.0.1:8765  LISTEN
127.0.0.1:7447  LISTEN
```

Inside the container, `xrdp`, `xrdp-sesman`, ROS 2, RViz, and the key transport packages were present:

```text
/usr/sbin/xrdp --nodaemon
/usr/sbin/xrdp-sesman --nodaemon
ROS2_OK
/opt/ros/jazzy/bin/rviz2
ros-jazzy-desktop 0.11.0-1noble.20260615.092556
ros-jazzy-rviz2 14.1.22-1noble.20260615.083715
ros-jazzy-compressed-image-transport 4.0.7-1noble.20260614.053443
ros-jazzy-point-cloud-transport 4.0.8-1noble.20260614.051508
ros-jazzy-rmw-cyclonedds-cpp 2.2.3-1noble.20260612.091852
```

`rviz2 --help` was not used as a pass/fail check because the Qt GUI binary aborts without an active display in a noninteractive `container exec` shell. Verify RViz visually through RDP.

## RDP and RViz Verification

RDP was verified from macOS with FreeRDP's SDL client:

```bash
sdl-freerdp /v:127.0.0.1:3389 /u:ros /p:ros /cert:ignore /size:1280x800 /dynamic-resolution
```

The KDE/xrdp session started on display `:10.0`. The session may lock automatically; unlock it with password `ros`.

The first RViz launch exposed a CycloneDDS socket buffer mismatch:

```text
failed to increase socket receive buffer size to at least 10485760 bytes, current is 8388608 bytes
rmw_create_node: failed to create domain
```

Linux reported default socket caps of `4194304` bytes:

```text
net.core.rmem_max = 4194304
net.core.wmem_max = 4194304
```

Raising the caps live to `16777216` bytes allowed an `8MB` CycloneDDS profile to pass `ros2 doctor --report`. The container entrypoint now applies that tuning at startup through `ROS2_SOCKET_BUFFER_BYTES`, and the repository CycloneDDS profile requests `8MB` send and receive buffers.

If socket tuning fails on a future runtime, lower `config/cyclonedds.xml` to `4MB` before running ROS graph tools.

The rebuilt container logs confirmed startup tuning:

```text
ROS 2 socket buffer caps set to 16777216 bytes.
```

The rebuilt container also reported:

```text
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
SocketReceiveBufferSize min="8MB"
SocketSendBufferSize min="8MB"
```

With the tuned runtime, `ros2 doctor --report` completed with:

```text
RMW MIDDLEWARE
middleware name : rmw_cyclonedds_cpp

ROS 2 INFORMATION
distribution name : jazzy
distribution status : active
```

RViz then launched successfully in the RDP session:

```text
[INFO] [rviz2]: Stereo is NOT SUPPORTED
[INFO] [rviz2]: OpenGl version: 4.5 (GLSL 4.5)
```

Visual proof for the tuned `8MB` profile was captured locally at `/private/tmp/ros2-rdp-rviz-8mb.png`.

## GitHub Pages Verification

GitHub Pages is enabled from `main` and `/docs`:

```text
URL: https://sandeep-devarapalli.github.io/ros2-mac-container/
Status: built
HTTPS enforced: true
```

The public URL returned `HTTP/2 200` and served `docs/index.html`.

The public simulator was exercised with a browser smoke test against the published URL. All sensor, compression, and network selector combinations updated metrics successfully:

```text
Exercised 32 public simulator combinations; 10 showed saturation warnings.
```

Local static checks also pass:

```bash
bash -n scripts/*.sh
node scripts/check_simulator.mjs
```

## Next Safe Step

The signed installer should still not be installed until local package signature validation succeeds. For now, use the source-built CLI path above, or complete Apple-documented source installation interactively with `sudo`, then rerun:

```bash
./scripts/preflight.sh
./scripts/build_container.sh
./scripts/start_container.sh
```
