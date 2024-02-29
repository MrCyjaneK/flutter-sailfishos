#!/bin/bash
pushd $(mktemp -d);
curl -L --output maliit-framework-wayland-2.2.1.zip https://github.com/sailfishos/maliit-framework/files/14410353/maliit-framework-wayland-2.2.1.zip;
unzip maliit-framework-wayland-2.2.1.zip;
zypper in RPMS/*.rpm;
popd