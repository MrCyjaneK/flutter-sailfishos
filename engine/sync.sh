#!/bin/sh
# Clone Flutter + gclient sync into /opt/flutter. Runs once as a Docker
# layer (ARG FLUTTER_VERSION / ENGINE_HASH). Do not call this at docker run.
set -eu

FLUTTER_VERSION=${FLUTTER_VERSION:?FLUTTER_VERSION is required}
ENGINE_HASH=${ENGINE_HASH:?ENGINE_HASH is required}
FLUTTER_REPO=${FLUTTER_REPO:-https://github.com/flutter/flutter.git}
DEST=${FLUTTER_ROOT:-/opt/flutter}

git config --global --add safe.directory '*' || true
git config --global protocol.version 2 || true

export PATH=/opt/depot_tools:$PATH
export DEPOT_TOOLS_UPDATE=0
export GCLIENT_PY3=1
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true

echo "sync: $FLUTTER_REPO @$FLUTTER_VERSION (engine.version $ENGINE_HASH)"

rm -rf "$DEST"
git clone --branch "$FLUTTER_VERSION" --single-branch "$FLUTTER_REPO" "$DEST"

cat >"$DEST/.gclient" <<GCLIENT
solutions = [
  {
    "managed": False,
    "name": ".",
    "url": "${FLUTTER_REPO}",
    "custom_deps": {},
    "deps_file": "DEPS",
    "safesync_url": "",
    "custom_vars": {
      "download_android_deps": False,
      "download_windows_deps": False,
      "download_fuchsia_deps": False,
      "download_jdk": False,
    },
  },
]
target_os = ["linux"]
GCLIENT

# CIPD has no flutter/java/openjdk/linux-arm64. DEPS always pulls it (the
# download_jdk var is unused). The embedder build does not need Java.
python3 - "$DEST/DEPS" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
text = p.read_text()
pat = r"('engine/src/flutter/third_party/java/openjdk':\s*\{)"
if re.search(pat, text) and "download_jdk" not in text.split("java/openjdk", 1)[1][:500]:
	text, n = re.subn(pat, r"\1\n    'condition': 'download_jdk',", text, count=1)
	if n != 1:
		sys.exit("sync: failed to patch openjdk out of DEPS")
	p.write_text(text)
	print("sync: skipped CIPD openjdk (no linux-arm64 package)")
PY

cd "$DEST"
export GCLIENT_SUPPRESS_GIT_VERSION_WARNING=1
n=0
while true; do
	log=$(mktemp)
	if gclient sync -D >"$log" 2>&1; then
		cat "$log"
		rm -f "$log"
		break
	fi
	cat "$log"
	if ! grep -qE 'RESOURCE_EXHAUSTED|rate limit exceeded' "$log"; then
		rm -f "$log"
		echo "sync: gclient failed (not a quota error)" >&2
		exit 1
	fi
	rm -f "$log"
	n=$((n + 1))
	if [ "$n" -ge 12 ]; then
		echo "sync: gclient failed after $n quota retries" >&2
		exit 1
	fi
	echo "sync: CIPD quota, retry $n in ${n}m" >&2
	sleep $((n * 60))
done

got=$(tr -d '[:space:]' <"$DEST/bin/internal/engine.version")
if [ "$got" != "$ENGINE_HASH" ]; then
	echo "sync: expected engine.version $ENGINE_HASH got $got" >&2
	exit 1
fi

# Dart SDK for this arch, baked into the same layer.
"$DEST/bin/flutter" --version
test -x "$DEST/bin/cache/dart-sdk/bin/dartaotruntime"

mkdir -p "$DEST/engine/src/out" "$DEST/bin/cache"
chmod -R a+rwX "$DEST/bin/cache" "$DEST/engine/src/out"

echo "sync: $DEST @$FLUTTER_VERSION ok"
