#!/bin/sh
# Native aarch64: libflutter_engine.so + gen_snapshot + a slim Flutter SDK
# for flutter-sfos-<ver>-devel (runs inside sfosbuild).
#
# Flutter + gclient live in the image at /opt/flutter (see sync.sh).
# Input env:
# ENGINE_HASH
# FLUTTER_VERSION
#
set -eu

HASH=${ENGINE_HASH:?ENGINE_HASH is required}
FLUTTER_VERSION=${FLUTTER_VERSION:?FLUTTER_VERSION is required}
JOBS=${NINJA_JOBS:-$(nproc)}

git config --global --add safe.directory '*' || true

export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
export PATH=/opt/depot_tools:$PATH
export DEPOT_TOOLS_UPDATE=0
export GCLIENT_PY3=1

FLUTTER_ROOT=${FLUTTER_ROOT:-/opt/flutter}
if [ ! -d "$FLUTTER_ROOT/.git" ]; then
	echo "engine: missing $FLUTTER_ROOT (rebuild the image: gclient is a Docker layer)" >&2
	exit 1
fi

echo "engine: $FLUTTER_ROOT @$FLUTTER_VERSION (engine.version $HASH) native aarch64"
got=$(tr -d '[:space:]' <"$FLUTTER_ROOT/bin/internal/engine.version")
if [ "$got" != "$HASH" ]; then
	echo "engine: expected engine.version $HASH got $got (rebuild image)" >&2
	exit 1
fi

SRC=$FLUTTER_ROOT/engine/src
NINJA_PATHS="$FLUTTER_ROOT/third_party/ninja:$SRC/flutter/third_party/ninja"
GN_BIN=$SRC/flutter/third_party/gn/gn
EMBEDDER_H=$SRC/flutter/shell/platform/embedder/embedder.h

OUTDIR=linux_release_arm64
OUT=$SRC/out/$OUTDIR
export PATH="$NINJA_PATHS:$PATH"

cd "$SRC"
if [ -x ./flutter/tools/gn ]; then
	./flutter/tools/gn \
		--runtime-mode=release \
		--target-os=linux \
		--linux-cpu=arm64 \
		--arm-float-abi=hard \
		--embedder-for-target \
		--disable-desktop-embeddings \
		--no-build-embedder-examples \
		--no-goma \
		--stripped
else
	echo "engine: missing $SRC/flutter/tools/gn" >&2
	exit 1
fi

if ! grep -q '^arm_cpu' "$OUT/args.gn" 2>/dev/null; then
	printf '\narm_cpu = "generic"\narm_tune = "generic"\n' >>"$OUT/args.gn"
	if [ -x "$GN_BIN" ]; then
		"$GN_BIN" gen "$OUT"
	else
		gn gen "$OUT"
	fi
fi

ninja -C "$OUT" -j"$JOBS" flutter/shell/platform/embedder:flutter_engine

# Prefer a gen_snapshot that runs on aarch64 (this container).
snap=
for c in "$OUT/gen_snapshot" "$OUT/clang_arm64/gen_snapshot"; do
	if [ -x "$c" ]; then
		snap=$c
		break
	fi
done
if [ -z "$snap" ]; then
	ninja -C "$OUT" -j"$JOBS" gen_snapshot || \
		ninja -C "$OUT" -j"$JOBS" clang_arm64/gen_snapshot
	for c in "$OUT/gen_snapshot" "$OUT/clang_arm64/gen_snapshot"; do
		if [ -x "$c" ]; then
			snap=$c
			break
		fi
	done
fi
if [ -z "$snap" ] || [ ! -x "$snap" ]; then
	echo "engine: no aarch64 gen_snapshot in $OUT" >&2
	exit 1
fi

# ELF e_machine 183 = EM_AARCH64
machine=$(od -An -t u2 -j 18 -N 2 "$snap" | awk '{print $1}')
if [ "$machine" != 183 ]; then
	echo "engine: gen_snapshot is not aarch64 (e_machine=$machine, expected 183)" >&2
	exit 1
fi

test -f "$OUT/libflutter_engine.so"
test -f "$OUT/icudtl.dat"
test -x "$snap"
test -f "$EMBEDDER_H"

export PATH="$FLUTTER_ROOT/bin:$PATH"
"$FLUTTER_ROOT/bin/flutter" --version
test -x "$FLUTTER_ROOT/bin/cache/dart-sdk/bin/dartaotruntime"

patched_src=
for d in \
	"$OUT/flutter_patched_sdk_product" \
	"$OUT/flutter_patched_sdk" \
	"$FLUTTER_ROOT/bin/cache/artifacts/engine/common/flutter_patched_sdk_product" \
	"$FLUTTER_ROOT/bin/cache/artifacts/engine/common/flutter_patched_sdk"
do
	if [ -d "$d" ]; then
		patched_src=$d
		break
	fi
done
if [ -z "$patched_src" ]; then
	"$FLUTTER_ROOT/bin/flutter" precache --linux || true
	for d in \
		"$FLUTTER_ROOT/bin/cache/artifacts/engine/common/flutter_patched_sdk_product" \
		"$FLUTTER_ROOT/bin/cache/artifacts/engine/common/flutter_patched_sdk"
	do
		if [ -d "$d" ]; then
			patched_src=$d
			break
		fi
	done
fi
if [ -z "$patched_src" ]; then
	echo "engine: missing flutter_patched_sdk" >&2
	exit 1
fi

mkdir -p /out/bin /out/sdk
install -m 755 "$OUT/libflutter_engine.so" /out/libflutter_engine.so
install -m 644 "$OUT/icudtl.dat" /out/icudtl.dat
install -m 644 "$EMBEDDER_H" /out/flutter_embedder.h
install -m 755 "$snap" /out/bin/gen_snapshot
printf 'aarch64\n' >/out/.arch

# Slim SDK: flutter tool + dart-sdk + packages. Engine source stays in the image.
tar -C "$FLUTTER_ROOT" \
	--exclude=.git \
	--exclude=engine \
	--exclude=.github \
	--exclude=dev \
	--exclude=examples \
	--exclude=docs \
	--exclude=bin/cache/downloads \
	--exclude=bin/cache/artifacts/engine/android \
	--exclude=bin/cache/artifacts/engine/ios \
	--exclude=bin/cache/artifacts/engine/darwin \
	--exclude=bin/cache/artifacts/engine/windows \
	--exclude=bin/cache/artifacts/engine/linux-x64 \
	-cf - . | tar -C /out/sdk -xf -

mkdir -p /out/sdk/bin/cache/artifacts/engine/common
rm -rf /out/sdk/bin/cache/artifacts/engine/common/flutter_patched_sdk_product
cp -a "$patched_src" /out/sdk/bin/cache/artifacts/engine/common/flutter_patched_sdk_product

test -x /out/sdk/bin/flutter
test -x /out/sdk/bin/cache/dart-sdk/bin/dartaotruntime
test -d /out/sdk/bin/cache/artifacts/engine/common/flutter_patched_sdk_product

# flutter tool requires $FLUTTER_ROOT/.git (we stripped the real one).
mkdir -p /out/sdk/.git
rev=$(git -C "$FLUTTER_ROOT" rev-parse HEAD 2>/dev/null || true)
if [ -z "$rev" ] && [ -f /out/sdk/bin/cache/flutter_tools.stamp ]; then
	rev=$(cut -d: -f1 /out/sdk/bin/cache/flutter_tools.stamp)
fi
printf '%s\n' "${rev:-$HASH}" >/out/sdk/.git/HEAD

if [ -n "${HOST_UID:-}" ]; then
	chown -R "$HOST_UID:${HOST_GID:-$HOST_UID}" /out
fi

echo "engine $HASH -> /out"
ls -lh /out/libflutter_engine.so /out/icudtl.dat /out/bin/gen_snapshot /out/flutter_embedder.h
ls -ld /out/sdk /out/sdk/bin/cache/dart-sdk
