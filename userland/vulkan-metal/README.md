# A135F Vulkan and Metal2Vulkan core

This directory builds and stages three iOS arm64 components:

- Khronos Vulkan Loader, which loads the PanVK ICD manifest.
- Mesa PanVK for the Exynos 850 Mali-G52.
- A Rust C-ABI adapter using the Metal2Vulkan runtime to create a Vulkan-backed runtime Device.

The adapter exposes only Vulkan device creation, name, registry ID and destruction. It is a foundation/smoke interface, **not** a complete Objective-C MTLDevice implementation. CoreAnimation still needs Metal objects and selectors backed by runtime queues, buffers, textures, encoders, pipelines and AIR shader translation. Do not enable it as the system renderer until that Objective-C bridge exists and device boot logs validate the PanVK command path.

## Build

First build these ignored workspace artifacts using the current Mesa cross build:

- userland/mesa/build/vulkan-loader-ios/loader/libvulkan.1.4.367.dylib
- userland/mesa/build/build-panvk3/src/panfrost/vulkan/libvulkan_panfrost.dylib

Then run userland/vulkan-metal/build.sh. It uses the WSL iOS SDK and Rust stable, builds a small on-device Vulkan device-creation utility, and writes package files to userland/vulkan-metal/out/.

## Install

For a diagnostic rootfs only, install.sh places the Vulkan device smoke utility, loader, PanVK ICD, runtime core and manifest into an already mounted rootfs. It refuses to overwrite any existing files. Running the utility after boot checks that PanVK can actually create a Vulkan device. The package still does not provide the Objective-C MTLDevice adapter required by CoreAnimation; do not enable it as the system renderer.
