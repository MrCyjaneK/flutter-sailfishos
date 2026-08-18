# hello

Counter sample. Sailfish bits live in `elinux/`; sfosbuild workspace is
this directory (`.sfosbuild/`).

```bash
./elinux/build.sh
./elinux/build.sh deploy
```

Needs runtime RPMs from the parent repo once (`make FLUTTER=3.41.9 engine runtime`), or `FLUTTER_SFOS_RPMS`. ExtraInstall runs `flutter-elinux build elinux`.

Launch on the device as **defaultuser**.
