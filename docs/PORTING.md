# Porting a Flutter app to Sailfish OS

Copy the app-side files into an existing Flutter project:

```bash
cp -a template/elinux your_app/elinux
cp -a template/.sfosbuild your_app/.sfosbuild
cp -a template/rpm your_app/rpm
# rename elinux/launcher.sh.in, elinux/app.desktop.in, rpm/app.yaml.in
# set BINARY_NAME in elinux/CMakeLists.txt
# set FLUTTER_VERSION in elinux/flutter-sfos.env
# ExtraInstall install= lines must match the renamed launcher/desktop
```

```bash
cd your_app
./elinux/build.sh              # flutter-elinux build + RPM inside sfosbuild
./elinux/build.sh deploy       # DEVICE=defaultuser@192.168.1.177
```

No host Flutter SDK is required. ExtraInstall runs stock
`flutter-elinux build elinux --release --target-arch=arm64 --target-backend-type=wayland`
in the aarch64 Sailfish image (plugins and native `.so` included). The
only Sailfish-specific step is overlaying our engine/embedder `.so` in
the flutter-elinux cache, then dropping those `.so` from the app RPM so
the device uses `flutter-sfos-<ver>`.

`elinux/CMakeLists.txt` and `elinux/flutter/CMakeLists.txt` are stock
flutter-elinux templates (`ephemeral/`). Do not point them at
`find_package(flutter-sfos)`.

## What you need (and what to host)

You do **not** need the Flutter engine source in the app repo.

**On the machine that builds the app**

- Docker + [sfosbuild](https://github.com/mrcyjanek/sfosbuild)
- Matching **device RPMs** (`flutter-sfos-<ver>` and `-devel`)  
  From this repo: `make FLUTTER=<ver> runtime` → `versions/<ver>/runtime/rpms/`  
  `FLUTTER_SFOS_RPMS=/path/to/rpms ./elinux/build.sh`

`-devel` ships the aarch64 Flutter SDK, `gen_snapshot`, and flutter-elinux.
ExtraInstall `rpm -Uvh`s it, then `flutter-sfos-aot` (the elinux driver).

**On the phone**

- `flutter-sfos-<ver>` (same pin as AOT). OpenRepos or `make deploy` from this repo.

**What to publish** if other people should build without this git tree

1. `flutter-sfos-<ver>` and `flutter-sfos-<ver>-devel` aarch64 RPMs (OpenRepos and/or GitHub Releases).

Engine/embedder source stays in *this* repo. App repos only consume those
RPMs plus `elinux/`, `rpm/`, and `.sfosbuild/`.

See `examples/hello/` (`./elinux/build.sh`).
