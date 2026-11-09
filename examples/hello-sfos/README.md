# hello_sfos

A new Flutter project. Sailfish packaging is `elinux/`, `rpm/`, and
`.sfosbuild/` (cyanek-sfos). Pinned to flutter-sfos 3.44.0.

```bash
cd examples/hello-sfos
sfosbuild --network --in-place 5.1.0.11 aarch64 rpm/hello-sfos.yaml
sfosbuild deploy defaultuser@192.168.1.177 rpm/hello-sfos.yaml
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
