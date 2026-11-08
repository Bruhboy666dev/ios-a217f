#!/bin/sh
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$1
[ -n "$root" ] || { echo "usage: install.sh MOUNTED_IOS_ROOT" >&2; exit 1; }
src="$here/out"
bin="$root/usr/local/bin"
lib="$root/usr/local/lib/a135f"
icd="$root/usr/local/share/vulkan/icd.d"
[ -f "$src/a135f-vulkan-smoke" ] && [ -f "$src/libvulkan.1.dylib" ] && [ -f "$src/libvulkan_panfrost.dylib" ] && [ -f "$src/liba135f_metal2vulkan.dylib" ] && [ -f "$src/a135f-panfrost.json" ] || {
  echo "install: run userland/vulkan-metal/build.sh first" >&2; exit 1;
}
[ -d "$root/System/Library/Extensions" ] || { echo "install: not an iOS root: $root" >&2; exit 1; }
for path in "$bin/a135f-vulkan-smoke" "$lib/libvulkan.1.dylib" "$lib/libvulkan_panfrost.dylib" "$lib/liba135f_metal2vulkan.dylib" "$icd/a135f-panfrost.json"; do
  [ ! -e "$path" ] || { echo "install: refusing to overwrite $path" >&2; exit 1; }
done
install -d "$bin" "$lib" "$icd" "$root/var/mobile/Library/Caches/a135f-metal2vulkan"
install -m 0755 "$src/a135f-vulkan-smoke" "$bin/a135f-vulkan-smoke"
install -m 0644 "$src/libvulkan.1.dylib" "$lib/libvulkan.1.dylib"
install -m 0755 "$src/libvulkan_panfrost.dylib" "$lib/libvulkan_panfrost.dylib"
install -m 0755 "$src/liba135f_metal2vulkan.dylib" "$lib/liba135f_metal2vulkan.dylib"
install -m 0644 "$src/a135f-panfrost.json" "$icd/a135f-panfrost.json"
echo "Installed Vulkan smoke utility, loader, PanVK ICD and Metal2Vulkan core into $root"
echo "This package does not replace the probe with a complete Objective-C MTLDevice."
