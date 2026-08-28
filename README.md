# Flutter for Sailfish OS

> I mean Silica is cool but there are things that go out of Qt5.6 fork that I may want to do...

## Downloads

- [3.41.9](https://github.com/MrCyjaneK/flutter-sailfishos/releases/tag/3.41.9-13)
- [3.44.0](https://github.com/MrCyjaneK/flutter-sailfishos/releases/tag/3.44.0-7)
## About

Versions in `versions/<ver>/pin.env`: **3.41.9**, **3.44.0**. Pass `FLUTTER=`
on every command.

The C++ embedder is Sony’s Wayland/EGL runner
([flutter-elinux/flutter-embedded-linux](https://github.com/flutter-elinux/flutter-embedded-linux)).
`libflutter_engine.so` and aarch64 `gen_snapshot` are built from source
(`make engine`, native aarch64 Docker, `--embedder-for-target` release).
Google’s `linux-arm64-embedder.zip` is debug/JIT and will not load AOT
`libapp.so`.

Runtimes install side by side under `/usr/lib64/flutter-sfos/<version>/`.
Apps `Requires:` the exact RPM they were AOT-compiled against.
App ExtraInstall is stock `flutter-elinux build elinux`; we overlay our
engine/embedder `.so` in the cache and omit those copies from the app RPM.

This is an OpenRepos-style extra runtime, not a Harbour-safe bundle.

## Host requirements

- Docker + [sfosbuild](https://github.com/mrcyjanek/sfosbuild)
- `git`

A host Flutter SDK is not required to build apps. First `make engine` is a
native aarch64 build (slow under qemu on x86). `gclient sync` is a Docker
layer on `flutter-sfos-engine:<ver>` (rebuilds only when the pin changes);
ninja `out/` is cached in `.cache/engine/<ver>/aarch64/`.

```bash
git clone https://github.com/mrcyjanek/flutter-sailfishos
cd flutter-sailfishos
make FLUTTER=3.44.0 engine
make FLUTTER=3.44.0 runtime hello
make FLUTTER=3.44.0 deploy DEVICE=defaultuser@192.168.1.177
```

Launch **as defaultuser**, not root:

```bash
ssh defaultuser@192.168.1.177
export $(systemctl --user show-environment)
flutter-hello
```

Pixel ratio follows Lipstick’s physical DPI (Flutter 160-dpi baseline);
override with `FLUTTER_SCALE`. Keyboard uses maliit-glib (SFOS ≥ 4.6).

## Porting an app

See [docs/PORTING.md](docs/PORTING.md). Copy [template/elinux](template/elinux),
[template/rpm](template/rpm), and [template/.sfosbuild](template/.sfosbuild)
into the app, then `./elinux/build.sh`.

## Adding a Flutter version

```bash
mkdir versions/X.Y.Z
cp versions/3.44.0/pin.env versions/X.Y.Z/pin.env
ln -s 3.44.0 patches/X.Y.Z          # or a real dir if patches change
# edit ENGINE_HASH / ELINUX_ENGINE_HASH (and EMBEDDER_REV / ELINUX_REV if those moved)
make FLUTTER=X.Y.Z engine runtime
```

## Layout

```
Makefile                            # engine / runtime / hello / deploy
versions/<ver>/pin.env              # ENGINE_HASH, ELINUX_ENGINE_HASH, EMBEDDER_REV, ELINUX_REV, RELEASE
patches/<ver>/                      # embedder diffs; symlink to a previous ver if unchanged
engine/                             # Dockerfile (linux/arm64)
examples/hello/                     # sample app; `./elinux/build.sh` → sfosbuild .
template/elinux/                    # copy into an app as elinux/
template/rpm/                       # copy into the app as rpm/
template/.sfosbuild/                # copy into the app root
template/runtime/                   # spec.in + cmake + flutter-elinux driver (stamped at make runtime)
```

Engine blobs are not committed (`.cache/engine/<ver>/`, `versions/<ver>/engine/`).
