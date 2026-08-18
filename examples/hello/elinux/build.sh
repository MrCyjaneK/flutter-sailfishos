#!/bin/sh
# From the Flutter app root:
#   ./elinux/build.sh          # flutter-elinux build + RPM inside sfosbuild
#   ./elinux/build.sh deploy
#   ./elinux/build.sh clean
#
# Needs:
#   FLUTTER_SFOS_RPMS  dir with flutter-sfos-<ver> and -devel RPMs
set -eu

cd "$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
ELINUX=$PWD/elinux
if [ -z "${FLUTTER_VERSION:-}" ]; then
	# shellcheck disable=SC1091
	. "$ELINUX/flutter-sfos.env"
fi
: "${FLUTTER_VERSION:?set FLUTTER_VERSION or elinux/flutter-sfos.env}"

RPMS=${FLUTTER_SFOS_RPMS:-$PWD/../../versions/$FLUTTER_VERSION/runtime/rpms}
SFOS=${SFOS:-5.1.0.11}
ARCH=${ARCH:-aarch64}
DEVICE=${DEVICE:-defaultuser@192.168.1.177}

if [ "${1:-}" = clean ]; then
	rm -rf build "$ELINUX"/rpms "$ELINUX"/out "$ELINUX"/bundle \
		"$ELINUX"/build-native rpms
	rm -f ./*.rpm "$ELINUX"/*.rpm
	for f in "$ELINUX"/*.in rpm/*.in; do
		[ -f "$f" ] && rm -f "${f%.in}"
	done
	exit 0
fi

test -d rpm
test -x "$ELINUX/build.sh"

for f in "$ELINUX"/*.in rpm/*.in; do
	[ -f "$f" ] || continue
	sed "s|@FLUTTER_VERSION@|$FLUTTER_VERSION|g" "$f" > "${f%.in}"
done
chmod +x "$ELINUX"/*.sh

rm -f ./flutter-sfos-"$FLUTTER_VERSION"-*.rpm
cp -f "$(ls -t "$RPMS"/flutter-sfos-"$FLUTTER_VERSION"-"$FLUTTER_VERSION"-*.aarch64.rpm | grep -v debug | head -1)" \
	"$(ls -t "$RPMS"/flutter-sfos-"$FLUTTER_VERSION"-devel-"$FLUTTER_VERSION"-*.aarch64.rpm | grep -v debug | head -1)" \
	./

sfosbuild "$SFOS" "$ARCH" .

if [ "${1:-}" = deploy ]; then
	sfosbuild deploy "$DEVICE" .
fi
