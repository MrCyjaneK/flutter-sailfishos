#!/bin/sh
# Stamp flutter-sfos.spec / aot and sfosbuild the runtime RPM.
# Skips when RPMs already match the pin, templates, engine, and embedder.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
# shellcheck disable=SC1091
. "$ROOT/scripts/env.sh"

SFOS=${SFOS:-5.1.0.11}
ARCH=${ARCH:-aarch64}
RELEASE=${RELEASE:-1}

RUNTIME=$VERDIR/runtime
SPEC_IN=$ROOT/template/runtime/flutter-sfos.spec.in
AOT_IN=$ROOT/template/runtime/flutter-sfos-aot.sh.in
CMAKE_IN=$ROOT/template/runtime/cmake/flutter-sfos-config.cmake.in
STAMP=$RUNTIME/.runtime-stamp
RPM=$RUNTIME/rpms/flutter-sfos-$FLUTTER-$FLUTTER-$RELEASE.$ARCH.rpm
DEVEL=$RUNTIME/rpms/flutter-sfos-$FLUTTER-devel-$FLUTTER-$RELEASE.$ARCH.rpm

stamp_payload() {
	printf '%s %s %s %s\n' "$ENGINE_HASH" "$RELEASE" "$SFOS" "$ARCH"
	cksum "$SPEC_IN" "$AOT_IN" "$CMAKE_IN"
	if [ -f "$VERDIR/engine/libflutter_engine.so" ]; then
		cksum "$VERDIR/engine/libflutter_engine.so"
	fi
	if [ -f "$RUNTIME/.embedder-stamp" ]; then
		cat "$RUNTIME/.embedder-stamp"
	fi
}

mkdir -p "$RUNTIME/rpm" "$RUNTIME/cmake"
sed -e "s|@FLUTTER_VERSION@|$FLUTTER|g" -e "s|@RELEASE@|$RELEASE|g" \
	"$SPEC_IN" >"$RUNTIME/rpm/flutter-sfos.spec"
sed -e "s|@FLUTTER_VERSION@|$FLUTTER|g" -e "s|@RELEASE@|$RELEASE|g" \
	"$AOT_IN" >"$RUNTIME/flutter-sfos-aot"
chmod +x "$RUNTIME/flutter-sfos-aot"
cp -f "$CMAKE_IN" "$RUNTIME/cmake/"

already() {
	[ -f "$RPM" ] || return 1
	[ -f "$DEVEL" ] || return 1
	if [ ! -f "$STAMP" ]; then
		return 0
	fi
	[ "$(stamp_payload)" = "$(cat "$STAMP")" ]
}

if [ "${FORCE:-}" != 1 ] && already; then
	stamp_payload >"$STAMP"
	echo "runtime $FLUTTER already packed ($ENGINE_HASH, $RELEASE)"
	echo "  make FLUTTER=$FLUTTER runtime FORCE=1  to rebuild"
	exit 0
fi

rm -rf "$RUNTIME/build-client" "$RUNTIME/build-so"
sfosbuild --in-place "$SFOS" "$ARCH" "$RUNTIME/rpm/flutter-sfos.spec"
stamp_payload >"$STAMP"
echo "runtime $FLUTTER -> $RUNTIME/rpms"
