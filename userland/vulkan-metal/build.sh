#!/bin/sh
set -eu
[ ! -f "$HOME/.cargo/env" ] || . "$HOME/.cargo/env"
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(CDPATH= cd -- "$here/../.." && pwd)
mesa_build="$repo/userland/mesa/build"
sdk="$HOME/ios-toolchain/sdk/iPhoneOS16.5.sdk"
loader="$mesa_build/vulkan-loader-ios/loader/libvulkan.1.4.367.dylib"
panvk="$mesa_build/build-panvk3/src/panfrost/vulkan/libvulkan_panfrost.dylib"

[ -d "$sdk" ] || { echo "build: missing iOS SDK: $sdk" >&2; exit 1; }
[ -f "$loader" ] || { echo "build: build the Khronos iOS loader first: $loader" >&2; exit 1; }
[ -f "$panvk" ] || { echo "build: build the PanVK iOS driver first: $panvk" >&2; exit 1; }

linker="$mesa_build/ios-rust-linker"
cat > "$linker" <<EOF
#!/bin/sh
exec clang -target arm64-apple-ios16.0 -fuse-ld=lld -isysroot "$sdk" "\$@"
EOF
chmod 0755 "$linker"

cd "$here"
RUSTUP_TOOLCHAIN=stable CARGO_HOME="$mesa_build/cargo-home" CARGO_TARGET_DIR="$mesa_build/metal2vulkan-target" CARGO_TARGET_AARCH64_APPLE_IOS_LINKER="$linker" SDKROOT="$sdk" cargo build --release --target aarch64-apple-ios

out="$here/out"
mkdir -p "$out"
cp -L "$loader" "$out/libvulkan.1.dylib"
cp "$panvk" "$out/libvulkan_panfrost.dylib"
cp "$mesa_build/metal2vulkan-target/aarch64-apple-ios/release/liba135f_metal2vulkan.dylib" "$out/"
install_name_tool=/usr/lib/llvm-18/bin/llvm-install-name-tool
[ -x "$install_name_tool" ] || { echo "build: missing LLVM install-name tool" >&2; exit 1; }
"$install_name_tool" -id /usr/local/lib/a135f/liba135f_metal2vulkan.dylib "$out/liba135f_metal2vulkan.dylib"
clang -target arm64-apple-ios16.0 -fuse-ld=lld -isysroot "$sdk" -O2 \
  -I"$here" -L"$out" -Wl,-rpath,/usr/local/lib/a135f \
  "$here/src/smoke.c" -la135f_metal2vulkan -o "$out/a135f-vulkan-smoke"
cat > "$out/a135f-panfrost.json" <<'JSON'
{
  "file_format_version": "1.0.0",
  "ICD": {
    "api_version": "1.4.305",
    "library_path": "/usr/local/lib/a135f/libvulkan_panfrost.dylib"
  }
}
JSON
llvm-nm -gU "$out/liba135f_metal2vulkan.dylib" | grep -q _a135f_m2v_device_create
echo "Built iOS arm64 core components and Vulkan smoke utility in $out"
ls -lh "$out"
