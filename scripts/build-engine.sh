#!/bin/sh
# Docker: native aarch64 release embedder + aarch64 gen_snapshot + slim SDK.
# gclient lives in the image (flutter-sfos-engine:<ver>); ninja out/ is on disk.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
# shellcheck disable=SC1091
. "$ROOT/scripts/env.sh"

if ! command -v docker >/dev/null; then
	echo "docker is required to build the engine" >&2
	exit 1
fi

CACHE=${ENGINE_CACHE:-$ROOT/.cache/engine/$FLUTTER/aarch64}
DEST="$VERDIR/engine"
RUNTIME_ENGINE="$VERDIR/runtime/engine"
IMAGE=${ENGINE_IMAGE:-flutter-sfos-engine:$FLUTTER}
STAMP="$DEST/.hash"
PLATFORM=linux/arm64

already() {
	[ -f "$DEST/libflutter_engine.so" ] || return 1
	[ -f "$DEST/icudtl.dat" ] || return 1
	[ -f "$DEST/flutter_embedder.h" ] || return 1
	[ -x "$DEST/bin/gen_snapshot" ] || return 1
	[ -x "$DEST/sdk/bin/flutter" ] || return 1
	[ -x "$DEST/sdk/bin/cache/dart-sdk/bin/dartaotruntime" ] || return 1
	[ "$(cat "$DEST/.arch" 2>/dev/null || true)" = aarch64 ] || return 1
	got=$(cat "$STAMP" 2>/dev/null || true)
	if [ -z "$got" ]; then
		printf '%s\n' "$ENGINE_HASH" >"$STAMP"
		return 0
	fi
	[ "$got" = "$ENGINE_HASH" ]
}

copy_runtime_bits() {
	mkdir -p "$RUNTIME_ENGINE" "$VERDIR/runtime/bin"
	cp -a "$DEST/flutter_embedder.h" "$DEST/libflutter_engine.so" "$DEST/icudtl.dat" \
		"$RUNTIME_ENGINE/"
	cp -a "$DEST/bin/gen_snapshot" "$VERDIR/runtime/bin/"
	if [ "${FORCE:-}" = 1 ] || [ ! -x "$VERDIR/runtime/sdk/bin/flutter" ]; then
		rm -rf "$VERDIR/runtime/sdk"
		cp -a "$DEST/sdk" "$VERDIR/runtime/sdk"
	fi
}

if [ "${FORCE:-}" != 1 ] && already; then
	echo "engine $FLUTTER already built ($ENGINE_HASH, aarch64)"
	echo "  make FLUTTER=$FLUTTER engine FORCE=1  to rebuild"
	if [ "${V:-}" = 1 ]; then
		ls -lh "$DEST/libflutter_engine.so" "$DEST/icudtl.dat" \
			"$DEST/bin/gen_snapshot" "$DEST/flutter_embedder.h"
	fi
	copy_runtime_bits
	exit 0
fi

mkdir -p "$CACHE/out" "$DEST/bin" "$RUNTIME_ENGINE"

echo "docker build --platform $PLATFORM $IMAGE"
docker build --platform "$PLATFORM" \
	--build-arg FLUTTER_VERSION="$FLUTTER_VERSION" \
	--build-arg ENGINE_HASH="$ENGINE_HASH" \
	--build-arg FLUTTER_REPO="${FLUTTER_REPO:-https://github.com/flutter/flutter.git}" \
	-t "$IMAGE" \
	"$ROOT/engine"

echo "docker run --platform $PLATFORM (ninja cache $CACHE/out)"
docker run --rm \
	--platform "$PLATFORM" \
	-e HOME=/tmp \
	-e HOST_UID="$(id -u)" \
	-e HOST_GID="$(id -g)" \
	-e ENGINE_HASH="$ENGINE_HASH" \
	-e FLUTTER_VERSION="$FLUTTER_VERSION" \
	-e NINJA_JOBS="${NINJA_JOBS:-}" \
	-v "$CACHE/out:/opt/flutter/engine/src/out" \
	-v "$DEST:/out" \
	-v "$ROOT/engine/build.sh:/usr/local/bin/build-engine:ro" \
	"$IMAGE"

test -f "$DEST/libflutter_engine.so"
test -f "$DEST/icudtl.dat"
test -f "$DEST/flutter_embedder.h"
test -x "$DEST/bin/gen_snapshot"
test -x "$DEST/sdk/bin/flutter"
test "$(cat "$DEST/.arch")" = aarch64

copy_runtime_bits
printf '%s\n' "$ENGINE_HASH" >"$STAMP"

echo "engine $ENGINE_HASH ($FLUTTER, aarch64) -> $DEST"
