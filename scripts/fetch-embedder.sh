#!/bin/sh
# Clone upstream into third_party/ (not submodules — pins differ per Flutter
# version), checkout the pin, apply patches, copy into versions/<ver>/runtime/src.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
# shellcheck disable=SC1091
. "$ROOT/scripts/env.sh"

EMBEDDER_REPO=${EMBEDDER_REPO:-https://github.com/flutter-elinux/flutter-embedded-linux.git}
ELINUX_REPO=${ELINUX_REPO:-https://github.com/flutter-elinux/flutter-elinux.git}

sync_repo() {
	path=$1
	url=$2
	rev=$3
	dest=$ROOT/$path

	if [ ! -d "$dest/.git" ] && [ ! -f "$dest/.git" ]; then
		rm -rf "$dest"
		git clone "$url" "$dest"
	fi
	if ! git -C "$dest" cat-file -e "$rev^{commit}" 2>/dev/null; then
		git -C "$dest" fetch origin "$rev"
	fi
	git -C "$dest" checkout --detach "$rev"
	got=$(git -C "$dest" rev-parse HEAD)
	if [ "$got" != "$rev" ]; then
		echo "$path: expected $rev got $got" >&2
		exit 1
	fi
	echo "ok $path @$rev"
}

SRC="$VERDIR/runtime/src/flutter-embedded-linux"
ELINUX_DEST="$VERDIR/runtime/flutter-elinux"
STAMP="$VERDIR/runtime/.embedder-stamp"
PATCHDIR=$ROOT/patches/$FLUTTER

stamp_payload() {
	printf '%s %s\n' "$EMBEDDER_REV" "$ELINUX_REV"
	if ls "$PATCHDIR/"*.patch >/dev/null 2>&1; then
		cksum "$PATCHDIR"/*.patch
	fi
}

already() {
	[ -f "$SRC/CMakeLists.txt" ] || return 1
	[ -f "$ELINUX_DEST/bin/flutter_elinux.dart" ] || return 1
	[ -f "$ELINUX_DEST/bin/flutter-elinux" ] || return 1
	[ -f "$STAMP" ] || return 1
	[ "$(stamp_payload)" = "$(cat "$STAMP")" ]
}

if [ "${FORCE:-}" != 1 ] && already; then
	echo "embedder $FLUTTER already fetched ($EMBEDDER_REV)"
	echo "  make FLUTTER=$FLUTTER embedder FORCE=1  to rebuild"
	exit 0
fi

sync_repo third_party/flutter-embedded-linux "$EMBEDDER_REPO" "$EMBEDDER_REV"
sync_repo third_party/flutter-elinux "$ELINUX_REPO" "$ELINUX_REV"

rm -rf "$SRC"
mkdir -p "$SRC"
tar -C "$ROOT/third_party/flutter-embedded-linux" \
	--exclude=.git -cf - . | tar -C "$SRC" -xf -

if ls "$PATCHDIR/"*.patch >/dev/null 2>&1; then
	for p in "$PATCHDIR/"*.patch; do
		echo "apply $(basename "$p")"
		patch -d "$SRC" -p1 < "$p"
	done
fi

rm -rf "$ELINUX_DEST"
mkdir -p "$ELINUX_DEST"
tar -C "$ROOT/third_party/flutter-elinux" \
	--exclude=.git --exclude=flutter --exclude=bin/cache \
	-cf - . | tar -C "$ELINUX_DEST" -xf -
test -f "$ELINUX_DEST/bin/flutter_elinux.dart"
test -f "$ELINUX_DEST/bin/flutter-elinux"

stamp_payload >"$STAMP"

echo "patched embedder ($FLUTTER) -> $SRC"
echo "flutter-elinux ($ELINUX_REV) -> $ELINUX_DEST"
