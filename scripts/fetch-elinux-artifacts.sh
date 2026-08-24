#!/bin/sh
# Download Sony flutter-elinux engine zips into the packed SDK cache so
# `flutter-elinux build` does not hit GitHub on every app ExtraInstall.
#
# Artifacts live at $FLUTTER_ROOT/bin/cache/artifacts/engine/elinux-* with
# stamp bin/cache/elinux-sdk.stamp (see flutter-elinux lib/elinux_cache.dart).
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
# shellcheck disable=SC1091
. "$ROOT/scripts/env.sh"

SDK=${ELINUX_ARTIFACTS_SDK:-$VERDIR/engine/sdk}
CACHE=$SDK/bin/cache/artifacts/engine
STAMP=$SDK/bin/cache/elinux-sdk.stamp
SHORT=$(printf '%s' "$ENGINE_HASH" | cut -c1-10)
BASE=https://github.com/flutter-elinux/flutter-embedded-linux/releases/download/$SHORT
DL=${ELINUX_ARTIFACTS_CACHE:-$ROOT/.cache/elinux-artifacts/$SHORT}

# Same list as ELinuxEngineArtifacts.getBinaryDirs(). All of them are
# required or flutter-elinux will fetch the missing ones.
ARTIFACTS='
elinux-common
elinux-arm64-debug
elinux-arm64-profile
elinux-arm64-release
elinux-x64-debug
elinux-x64-profile
elinux-x64-release
'

if [ ! -d "$SDK/bin/cache" ]; then
	echo "elinux-artifacts: missing SDK cache at $SDK (build the engine first)" >&2
	exit 1
fi

up_to_date() {
	[ -f "$STAMP" ] || return 1
	[ "$(tr -d '[:space:]' <"$STAMP")" = "$ENGINE_HASH" ] || return 1
	for d in $ARTIFACTS; do
		[ -d "$CACHE/$d" ] || return 1
	done
}

if [ "${FORCE:-}" != 1 ] && up_to_date; then
	echo "elinux artifacts $SHORT already in $CACHE"
	exit 0
fi

if ! command -v unzip >/dev/null; then
	echo "elinux-artifacts: unzip is required" >&2
	exit 1
fi

mkdir -p "$DL" "$CACHE" "$SDK/bin/cache"
echo "elinux-artifacts: $BASE -> $CACHE"

for d in $ARTIFACTS; do
	zip=$d.zip
	if [ ! -s "$DL/$zip" ]; then
		echo "  download $zip"
		curl -fL --retry 3 --retry-delay 2 -o "$DL/$zip.part" "$BASE/$zip"
		mv -f "$DL/$zip.part" "$DL/$zip"
	fi
	rm -rf "$CACHE/$d"
	mkdir -p "$CACHE/$d"
	unzip -q -o "$DL/$zip" -d "$CACHE/$d"
	# Some zips wrap a single top-level folder named after the artifact.
	if [ -d "$CACHE/$d/$d" ] && [ "$(find "$CACHE/$d" -mindepth 1 -maxdepth 1 | wc -l)" -eq 1 ]; then
		tmp=$CACHE/$d.tmp
		rm -rf "$tmp"
		mv "$CACHE/$d/$d" "$tmp"
		rm -rf "$CACHE/$d"
		mv "$tmp" "$CACHE/$d"
	fi
	test -d "$CACHE/$d"
done

printf '%s\n' "$ENGINE_HASH" >"$STAMP"
echo "elinux-artifacts $SHORT ok"
