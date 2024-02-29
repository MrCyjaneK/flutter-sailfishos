# Flutter for SailfishOS

> Big thanks to Mister_Magister and TheKit

# Preparing enviorment

```bash
  [host] $ ssh -p 2222 -i ~/SailfishOS/vmshare/ssh/private_keys/sdk mersdk@localhost
[mersdk] $ sdk-assistant create SailfishOS-latest-aarch64 https://releases.sailfishos.org/sdk/targets/Sailfish_OS-latest-Sailfish_SDK_Target-aarch64.tar.7z
[mersdk] $ sb2 -t SailfishOS-latest-aarch64 -R bash -l
   [sb2] $ uname -m # should output aarch64
   [sb2] $ zypper in git clang libxkbcommon-devel wayland-protocols-devel wayland-client wayland-egl-devel make glibc-static

```

# Installing Flutter

```bash
[mersdk] $ sb2 -t SailfishOS-latest-aarch64 -R bash -l
   [sb2] $ mkdir flutter-elinux
   [sb2] $ git clone https://github.com/sony/flutter-elinux.git flutter-elinux/$(uname -m)
   [sb2] $ echo 'export PATH="$PATH:$HOME/flutter-elinux/$(uname -m)/bin"' >> $HOME/.bashrc
   [sb2] $ echo 'export PATH="$PATH:$HOME/flutter-elinux/$(uname -m)/flutter/bin"' >> $HOME/.bashrc
   [sb2] $ echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> $HOME/.bashrc
   [sb2] $ ln -s $HOME/.bashrc $HOME/.profile
   [sb2] $ bash # to reload the variables
   [sb2] $ git config --global --add safe.directory $HOME/flutter-elinux/$(uname -m)/flutter
   [sb2] $ flutter-elinux doctor # ignore errors, if `[✓] eLinux toolchain' is green then we good
   [sb2] $ flutter-elinux precache # This will download tools, feel free to skip but flutter tool will then download them at runtime, which is something that (I, personally) don't really enjoy. 
   [sb2] $ # Go, create some apps!
```

# Building flutter embedder

```bash
[mersdk] $ sb2 -t SailfishOS-latest-aarch64 -R bash -l
   [sb2] $ git clone https://github.com/MrCyjaneK/flutter-embedded-linux
   [sb2] $ cd flutter-embedded-linux
   [sb2] $ mkdir build && cd build
   [sb2] $ curl -L https://github.com/sony/flutter-embedded-linux/releases/download/f40e976bed/elinux-arm64-release.zip --output elinux-arm64-release.zip
   [sb2] $ unzip elinux-arm64-release.zip && rm elinux-arm64-release.zip
   [sb2] $ cmake ..
   [sb2] $ make -j$(nproc)
   [sb2] $ # Done! You should have flutter-client file in current directory
   [sb2] $ mkdir -p $SAILFISH_SDK_SRC1_MOUNT_POINT/SailfishOS/flutter/$(uname -m)
   [sb2] $ cp flutter-client $SAILFISH_SDK_SRC1_MOUNT_POINT/SailfishOS/flutter/$(uname -m)
```

# Porting existing flutter apps

I'll be porting unnamed_monero_wallet, which is an app of mine, it uses `dart:ffi`, native platform channels, custom pub registry - all the things that could possibly cause problems when porting.

If you don't support flutter-elinux **yet** make sure to enable this target by doing something along the lines of (don't forget to cleanup unwanted parts like test/ directory or .metadata afterwards):

```bash
[host] $ flutter-elinux create --platforms elinux .
```

Then, make sure that the app actually works.

```bash
[host] $ flutter-elinux run
```

Then proceed and build your app for sfos

```bash
[sb2] $ flutter-elinux pub get # NOTE: dependency management will be broken on the other side at all times. If you can't compile just run pub get and it should fix everything.
[sb2] $ flutter-elinux build elinux --release 
[sb2] $ cp $SAILFISH_SDK_SRC1_MOUNT_POINT/SailfishOS/flutter/$(uname -m)/flutter-client build/elinux/arm64/release/bundle/flutter-client
# note: replace unnamed_monero_wallet with the output binary name that you are using
[sb2] $ cat > build/elinux/arm64/release/bundle/unnamed_monero_wallet <<EOF
#!/bin/bash
cd \$(dirname \$0)
killall flutter-client || true

FLUTTER_LOG_LEVELS=TRACE LD_PRELOAD=\$PWD/lib/libflutter_engine.so ./flutter-client --bundle=\$PWD --fullscreen --force-scale-factor=3
EOF
[sb2] $ chmod +x build/elinux/arm64/release/bundle/unnamed_monero_wallet
[sb2] $ cat > elinux/sailfishos.spec <<EOF
# TBD:
EOF
[sb2] $ rpmbuild -bb elinux/sailfishos.spec --define "_bundledir $PWD/build/elinux/arm64/release/bundle/" --define "_sourcedir $PWD"
```

# Workarounds / fixes

## None of the required 'maliit-glib' found

```bash
# link comes from https://github.com/sailfishos/maliit-framework/files/14410353/maliit-framework-wayland-2.2.1.zip
[sb2] $ pushd $(mktemp -d)
[sb2] $ curl -L --output maliit-framework-wayland-2.2.1.zip https://github.com/sailfishos/maliit-framework/files/14410353/maliit-framework-wayland-2.2.1.zip
[sb2] $ unzip maliit-framework-wayland-2.2.1.zip
[sb2] $ zypper in RPMS/*.rpm
[sb2] $ popd
```

## fatal error: 'linux/input-event-codes.h' file not found

```
[sb2] $ curl -L --output /usr/include/linux/input-event-codes.h https://raw.githubusercontent.com/torvalds/linux/master/include/uapi/linux/input-event-codes.h
```