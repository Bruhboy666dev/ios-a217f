#!/bin/bash
# Mesa 25.0.7 with panfrost (the Mali) and softpipe (the fallback), as the OpenGL ES library behind src/eagl.c.
# Fetches the release, applies mesa/patches/*.patch and apply-panfrost-darwin.py, builds libOSMesa.8.dylib
# (install name /usr/local/lib/a135f/libOSMesa.8.dylib) into mesa/out.
#
# Needs: meson, ninja, bison, flex, python3 (venv; Mako, PyYAML, packaging), llvm-ar, and for panfrost
# Mesa's own host tool mesa_clc (LLVM + libclc + SPIRV-Tools + SPIRV-LLVM-Translator on the BUILD machine):
# step 1 builds it natively, step 2 cross-builds against it.
#
#   SDK, CC, CXX as for ../build.sh        DRIVERS=softpipe,panfrost (default)
#
# NOT verified: apply-panfrost-darwin.py was written without Mesa's source at hand (it names every edit it
# cannot place), and no Mesa build was run for this. Read mesa/README-mesa.txt first.
set -e
HERE=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
VERSION=25.0.7
SHA256=592272df3cf01e85e7db300c449df5061092574d099da275d19e97ef0510f8a6
B=$HERE/build
if [ -z "$SDK" ]; then
	if command -v xcrun >/dev/null 2>&1; then SDK=$(xcrun --sdk iphoneos --show-sdk-path)
	else SDK=${THEOS:-$HOME/theos}/sdks/iPhoneOS16.5.sdk; fi
fi
CC=${CC:-${IOS_CC:-clang -target arm64-apple-ios16.0}}
CXX=${CXX:-${IOS_CXX:-clang++ -target arm64-apple-ios16.0}}
DRIVERS=${DRIVERS:-softpipe,panfrost}
mkdir -p "$B/out" "$HERE/out"; cd "$B"

[ -f mesa-$VERSION.tar.xz ] || curl -sL --fail -o mesa-$VERSION.tar.xz https://archive.mesa3d.org/mesa-$VERSION.tar.xz
echo "$SHA256  mesa-$VERSION.tar.xz" | sha256sum -c --quiet
rm -rf mesa-$VERSION; tar xJf mesa-$VERSION.tar.xz
for p in "$HERE"/patches/*.patch; do patch -s --no-backup-if-mismatch -d mesa-$VERSION -p1 < "$p"; done
python3 "$HERE/apply-panfrost-darwin.py" mesa-$VERSION   # exits 1 and names what it could not place

if [ ! -x venv/bin/python3 ]; then python3 -m venv venv; venv/bin/pip -q install mako pyyaml packaging; fi
export PATH=$B/host/bin:$B/venv/bin:$PATH

# 1. the host tool panfrost's precompiled shaders need
if [ ! -x host/bin/mesa_clc ]; then
	CC=clang CXX=clang++ meson setup build-host mesa-$VERSION --prefix=$B/host -Dllvm=enabled -Dgallium-drivers= -Dvulkan-drivers= \
		-Dplatforms= -Dglx=disabled -Degl=disabled -Dgbm=disabled -Dmesa-clc=enabled -Dinstall-mesa-clc=true \
		-Dprecomp-compiler=enabled -Dinstall-precomp-compiler=true -Dtools= -Dbuild-tests=false > meson-host.log
	ninja -C build-host install > ninja-host.log
fi

# 2. the library for the phone
cat > cross.ini <<INI
[binaries]
c = [$(printf "'%s', " $CC | sed 's/, $//'), '-isysroot', '$SDK']
cpp = [$(printf "'%s', " $CXX | sed 's/, $//'), '-isysroot', '$SDK', '-fuse-cxa-atexit']
objc = [$(printf "'%s', " $CC | sed 's/, $//'), '-isysroot', '$SDK']
ar = 'llvm-ar'
ranlib = 'llvm-ranlib'
strip = 'llvm-strip'
pkg-config = 'false'

[built-in options]
c_args = ['-DHAVE_STRUCT_TIMESPEC', '-D_DARWIN_C_SOURCE', '-DHAVE_DLFCN_H', '-DHAVE_FUNC_ATTRIBUTE_PACKED']
cpp_args = ['-DHAVE_STRUCT_TIMESPEC', '-D_DARWIN_C_SOURCE', '-DHAVE_DLFCN_H', '-DHAVE_FUNC_ATTRIBUTE_PACKED']

[host_machine]
system = 'darwin'
subsystem = 'ios'
cpu_family = 'aarch64'
cpu = 'arm64'
endian = 'little'

[properties]
needs_exe_wrapper = true
INI
cat > native.ini <<INI
[binaries]
mesa_clc = '$B/host/bin/mesa_clc'
INI
BUILD=build-${DRIVERS//,/-}
[ -f $BUILD/build.ninja ] || meson setup $BUILD mesa-$VERSION --native-file native.ini --cross-file cross.ini --wrap-mode=nofallback \
	--prefix=/usr/local --libdir=lib/a135f --buildtype=release -Db_ndebug=true \
	-Dplatforms= -Dgallium-drivers="$DRIVERS" -Dvulkan-drivers= -Dglx=disabled -Degl=disabled -Dgbm=disabled \
	-Dosmesa=true -Dllvm=disabled -Dshared-glapi=enabled -Dgles1=disabled -Dgles2=enabled -Dopengl=true \
	-Dmesa-clc=system -Dprecomp-compiler=system \
	-Dzstd=disabled -Dxmlconfig=disabled -Dexpat=disabled -Dshader-cache=disabled -Dvalgrind=disabled \
	-Dlibunwind=disabled -Dglvnd=disabled -Dvideo-codecs= -Dtools= -Dgallium-vdpau=disabled -Dgallium-va=disabled \
	-Dgallium-xa=disabled -Dlmsensors=disabled -Dbuild-tests=false > meson-setup.log
ninja -C $BUILD > ninja.log

O=$HERE/out
llvm-strip -x -o $O/libOSMesa.8.dylib $BUILD/src/gallium/targets/osmesa/libOSMesa.8.dylib
if [ -n "$INSTALL_NAME_TOOL" ]; then
	"$INSTALL_NAME_TOOL" -id /usr/local/lib/a135f/libOSMesa.8.dylib "$O/libOSMesa.8.dylib"
elif command -v llvm-install-name-tool >/dev/null 2>&1; then
	llvm-install-name-tool -id /usr/local/lib/a135f/libOSMesa.8.dylib "$O/libOSMesa.8.dylib"
elif command -v install_name_tool >/dev/null 2>&1; then
	install_name_tool -id /usr/local/lib/a135f/libOSMesa.8.dylib "$O/libOSMesa.8.dylib"
else
	ID=$(llvm-objdump --macho --dylib-id "$O/libOSMesa.8.dylib" | tail -n 1)
	[ "$ID" = /usr/local/lib/a135f/libOSMesa.8.dylib ] || { echo "mk-mesa.sh: OSMesa install name is $ID" >&2; exit 1; }
fi
${NM:-llvm-nm} -gU $O/libOSMesa.8.dylib | awk '$3 ~ /^_gl/ { print substr($3, 2) }' > $O/exported-gl.txt
cp mesa-$VERSION/src/mapi/glapi/registry/gl.xml $O/gl.xml
echo "mk-mesa.sh: Mesa $VERSION ($DRIVERS): $O/libOSMesa.8.dylib, $(stat -c %s $O/libOSMesa.8.dylib) bytes, $(wc -l < $O/exported-gl.txt) gl* functions"
