# Sailfish tree for a Flutter app

```bash
cp -a template/elinux your_app/elinux
cp -a template/.sfosbuild your_app/.sfosbuild
cp -a template/rpm your_app/rpm
```

Rename `elinux/launcher.sh.in`, `elinux/app.desktop.in`, `rpm/app.yaml.in`.
Set `BINARY_NAME` in `elinux/CMakeLists.txt` and `FLUTTER_VERSION` in
`elinux/flutter-sfos.env`. Then `./elinux/build.sh`.

`sfosbuild` packages the **app root** (Dart + `elinux/` + `rpm/`). ExtraInstall
runs `flutter-elinux build elinux` (engine/embedder `.so` swapped for ours).

The launcher execs `$BUNDLE/$BINARY_NAME`. Engine `.so` files stay in
`flutter-sfos-<ver>`; they are removed from the app RPM.
