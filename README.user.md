# How to fix flutter apps on SFOS?

1. Open terminal
2. Paste the following snipped

```bash
pushd $(mktemp -d);
curl -L --output maliit-framework-wayland-2.2.1.zip https://github.com/sailfishos/maliit-framework/files/14410353/maliit-framework-wayland-2.2.1.zip;
unzip maliit-framework-wayland-2.2.1.zip;
zypper in RPMS/*.rpm;
popd
```

[raw link to the code](https://git.mrcyjanek.net/mrcyjanek/flutter-sailfishos/raw/branch/master/fix.sh)

# Why?

In 4.6 changes required to run flutter apps will be in the os already, as for now this change is required to get glib api from SailfishOS/maliit-framework