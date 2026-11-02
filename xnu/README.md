# XNU for Galaxy A13 and Galaxy A21s (Exynos850)

The A13 kernel target is A135F. The A21s target is A217F, added by
xnu/patches/0029-a217f-machine-profile.patch. Both profiles compile the shared
Exynos850 board implementation originally introduced for A13: GIC-400 (GICv2),
eight Cortex-A55 cores, DW-MSHC eMMC, framebuffer, TD4150 touch support, and
Mali-G52. The A217F profile selects the same plain arm64 ABI and board support
macros; the ADT and shim carry A21s-specific RAM and display dimensions.

Builds run on GitHub macOS arm64 runners using blacktop/darwin-xnu-build at a
pinned commit. MACOS_VERSION 13.5 selects xnu-8796.141.3 (iOS 16.6/16.7 era).
The workflow applies staged third-party sources and all patches in order.

Dispatch xnu.yml with machine_config=A217F for the A21s kernel; the artifact
is kernel-development-a217f. Keep using A135F for the A13. The general
xnu-kernel artifact contains all produced kernel variants.
