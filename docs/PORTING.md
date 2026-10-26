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

`-devel` ships a full aarch64 Flutter SDK (real git checkout and default
`flutter precache`), `gen_snapshot`, and flutter-elinux. ExtraInstall
`rpm -Uvh`s it, then `flutter-sfos-aot` (the elinux driver).

**On the phone**

- `flutter-sfos-<ver>` (same pin as AOT). OpenRepos or `make deploy` from this repo.

**What to publish** if other people should build without this git tree

1. `flutter-sfos-<ver>` and `flutter-sfos-<ver>-devel` aarch64 RPMs (OpenRepos and/or GitHub Releases).

Engine/embedder source stays in *this* repo. App repos only consume those
RPMs plus `elinux/`, `rpm/`, and `.sfosbuild/`.

See `examples/hello/` (`./elinux/build.sh`).

## Camera cut-outs

Apps run full screen, so content is drawn under the camera cut-out. The
runtime reads the cut-out from the device's Silica settings and sends it on the
`flutter-sfos/display_cutouts` channel, but the Flutter embedder API can't set
`MediaQuery.padding`, so the app has to apply it.

The message is JSON, in physical pixels for the current orientation. It is sent
at start-up and whenever the orientation changes:

```json
{"version": 1,
 "padding": {"top": 66, "right": 0, "bottom": 0, "left": 0},
 "cutouts": [{"left": 310, "top": 0, "width": 414, "height": 66}]
}
```

`version` changes only if the format changes incompatibly.

Add `lib/sfos_cutouts.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final _padding = ValueNotifier<EdgeInsets>(EdgeInsets.zero); // physical px

void listenForDisplayCutouts() {
  const BasicMessageChannel<Object?>(
    'flutter-sfos/display_cutouts',
    JSONMessageCodec(),
  ).setMessageHandler((message) async {
    final p = (message! as Map)['padding'] as Map;
    double v(String k) => (p[k] as num).toDouble();
    _padding.value = EdgeInsets.fromLTRB(
      v('left'),
      v('top'),
      v('right'),
      v('bottom'),
    );
    return null;
  });
}

Widget cutoutPadding(BuildContext context, Widget? child) {
  return ValueListenableBuilder<EdgeInsets>(
    valueListenable: _padding,
    builder: (context, padding, _) {
      final mq = MediaQuery.of(context);
      final extra = padding / mq.devicePixelRatio;
      return MediaQuery(
        data: mq.copyWith(
          padding: mq.padding + extra,
          viewPadding: mq.viewPadding + extra,
        ),
        child: child!,
      );
    },
  );
}
```

then, in `lib/main.dart`, import it and start listening before `runApp`:

```dart
import 'sfos_cutouts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // needed before using a channel
  listenForDisplayCutouts();
  runApp(const MyApp());
}
```

and add the builder wherever the app creates its `MaterialApp` (in
`MyApp.build` for a project made with `flutter create`):

```dart
return MaterialApp(
  builder: cutoutPadding,
  title: 'Flutter Demo',
  // ...the rest unchanged
);
```

If the `MaterialApp` already has a `builder`, wrap it:
`builder: (context, child) => cutoutPadding(context, yourBuilder(context, child))`.

`AppBar` then draws its background behind the cut-out and keeps its contents
below it, and `SafeArea` and scroll views keep clear of it, as on a phone with
a notch. On other platforms nothing is sent and nothing changes. Needs a
`flutter-sfos` runtime with patch 0009.
