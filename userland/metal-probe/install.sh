#!/bin/sh
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=${1:?usage: install.sh MOUNTED_ROOT}
bundle="$here/out/A135FMetalProbe.bundle"
dest="$root/System/Library/Extensions/A135FMetalProbe.bundle"
[ -f "$bundle/A135FMetalProbe" ] && [ -f "$bundle/Info.plist" ] || {
	echo "install.sh: build the bundle first" >&2
	exit 1
}
[ -d "$root/System/Library/Extensions" ] || {
	echo "install.sh: not an iOS root: $root" >&2
	exit 1
}
[ ! -e "$dest" ] || {
	echo "install.sh: refusing to overwrite $dest" >&2
	exit 1
}
install -d "$dest"
cp "$bundle/A135FMetalProbe" "$dest/A135FMetalProbe"
cp "$bundle/Info.plist" "$dest/Info.plist"
chmod 0755 "$dest" "$dest/A135FMetalProbe"
chmod 0644 "$dest/Info.plist"
echo "installed $dest"
