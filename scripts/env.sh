# Source after setting ROOT. FLUTTER=<ver> is required.
# Sets VERDIR, FLUTTER_VERSION, and the pin variables.
if [ -z "${ROOT:-}" ]; then
	echo "env.sh: ROOT is not set" >&2
	exit 1
fi

if [ -z "${FLUTTER:-}" ]; then
	echo "set FLUTTER=<ver>, e.g. FLUTTER=3.44.0" >&2
	ls -1 "$ROOT"/versions/*/pin.env 2>/dev/null \
		| sed 's|.*/versions/||;s|/pin.env||' \
		| sed 's/^/  /' >&2 || true
	exit 1
fi

VERDIR=$ROOT/versions/$FLUTTER
if [ ! -f "$VERDIR/pin.env" ]; then
	echo "unknown Flutter version '$FLUTTER' (no $VERDIR/pin.env)" >&2
	exit 1
fi
# shellcheck disable=SC1091
. "$VERDIR/pin.env"
FLUTTER_VERSION=$FLUTTER
