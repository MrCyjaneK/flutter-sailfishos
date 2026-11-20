%global debug_package %{nil}

# Precache cache contains ELF that must not become RPM Requires:
# android and linux-x64 gen_snapshot, and linux-arm64 libflutter_linux_gtk.so.
%global __requires_exclude_from %{_datadir}/flutter-sfos/.*
%global __provides_exclude_from %{_datadir}/flutter-sfos/.*

Name:           flutter-sfos-3.44.0
Version:        3.44.0
Release:        8
Summary:        Flutter %{version} runtime for Sailfish OS
License:        BSD-3-Clause
URL:            https://github.com/flutter-elinux/flutter-embedded-linux
Source0:        %{name}-%{version}.tar.bz2

BuildRequires:  git
BuildRequires:  curl
BuildRequires:  unzip
BuildRequires:  xz
BuildRequires:  python3-base
BuildRequires:  python3-curses
BuildRequires:  python3-yaml
BuildRequires:  python3-setuptools
BuildRequires:  clang
BuildRequires:  cmake
BuildRequires:  make
BuildRequires:  pkgconfig
BuildRequires:  patchelf
BuildRequires:  binutils
BuildRequires:  pkgconfig(xkbcommon)
BuildRequires:  pkgconfig(wayland-client)
BuildRequires:  pkgconfig(wayland-cursor)
BuildRequires:  pkgconfig(wayland-egl)
BuildRequires:  pkgconfig(wayland-protocols)
BuildRequires:  pkgconfig(egl)
BuildRequires:  pkgconfig(glesv2)
BuildRequires:  pkgconfig(maliit-glib)
Requires:       maliit-framework-wayland-glib
Provides:       flutter-sfos = %{version}

%description
Versioned Flutter embedder for Sailfish OS.

%package devel
Summary:        Headers, flutter-elinux, and AOT toolchain for Flutter %{version}
Requires:       %{name} = %{version}
Requires:       git
Requires:       unzip
Requires:       curl
# Bundled SDK/cache ELF is not linked against the Sailfish sysroot.
AutoReqProv:    no

%description devel
Headers, cpp_client_wrapper, CMake package, aarch64 gen_snapshot, a full
Flutter SDK (real git checkout + default precache), and flutter-elinux so
an app's ExtraInstall can run `flutter-elinux build elinux` (our
engine/embedder .so overlay the cache).

%prep
%setup -q

%build
set -eu
export FLUTTER=%{version}
export ROOT=$PWD
# shellcheck disable=SC1091
. scripts/env.sh
export FLUTTER_VERSION ENGINE_HASH ELINUX_ENGINE_HASH EMBEDDER_REV ELINUX_REV

if [ ! -x /usr/bin/python ] && [ ! -x /usr/local/bin/python ]; then
	ln -sf /usr/bin/python3 /usr/local/bin/python
fi
# Same commit the depot-tools scratch package was built from.
rm -rf /opt/depot_tools
git init /opt/depot_tools
git -C /opt/depot_tools fetch --depth 1 \
	https://chromium.googlesource.com/chromium/tools/depot_tools.git \
	e923de63bfc631d5a09ef5324635d008d50dc0ca
git -C /opt/depot_tools checkout FETCH_HEAD
touch /opt/depot_tools/.disable_auto_update
export PATH=/opt/depot_tools:$PATH
export DEPOT_TOOLS_UPDATE=0
export GCLIENT_PY3=1
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0=*

command -v gclient
command -v cipd
cipd version

export FLUTTER_ROOT=/opt/flutter
sh engine/sync.sh
sh engine/build.sh

export ELINUX_ARTIFACTS_SDK=/out/sdk
sh scripts/fetch-elinux-artifacts.sh
sh scripts/fetch-embedder.sh

runtime=versions/%{version}/runtime
mkdir -p "$runtime/engine" "$runtime/bin"
cp -a /out/libflutter_engine.so /out/icudtl.dat /out/flutter_embedder.h "$runtime/engine/"
cp -a /out/bin/gen_snapshot "$runtime/bin/"
rm -rf "$runtime/sdk"
cp -a /out/sdk "$runtime/sdk"

libdir=%{_libdir}/flutter-sfos/%{version}
src=$runtime/src/flutter-embedded-linux
test -f "$runtime/engine/libflutter_engine.so"
test -f "$runtime/bin/gen_snapshot"
test -f "$runtime/sdk/bin/flutter"
test -d "$src"
test -f "$runtime/flutter-elinux/bin/flutter_elinux.dart"

chmod +x "$runtime/bin/gen_snapshot" "$runtime/flutter-elinux/bin/flutter-elinux"
find "$runtime/sdk/bin" -type f -exec chmod a+x {} +

mkdir -p "$src/build"
cp -f "$runtime/engine/libflutter_engine.so" "$src/build/libflutter_engine.so"

export CC=clang
export CXX=clang++

cmake -S "$src" -B build-client \
	-DCMAKE_BUILD_TYPE=Release \
	-DFLUTTER_RELEASE=ON \
	-DBACKEND_TYPE=WAYLAND \
	-DBUILD_ELINUX_SO=OFF \
	-DUSER_PROJECT_PATH=examples/flutter-wayland-client \
	-DFLUTTER_SFOS_LIBDIR="$libdir" \
	-DCMAKE_C_COMPILER=clang \
	-DCMAKE_CXX_COMPILER=clang++
cmake --build build-client -j"$(getconf _NPROCESSORS_ONLN)"

cmake -S "$src" -B build-so \
	-DCMAKE_BUILD_TYPE=Release \
	-DFLUTTER_RELEASE=ON \
	-DBACKEND_TYPE=WAYLAND \
	-DBUILD_ELINUX_SO=ON \
	-DFLUTTER_SFOS_LIBDIR="$libdir" \
	-DCMAKE_C_COMPILER=clang \
	-DCMAKE_CXX_COMPILER=clang++
cmake --build build-so -j"$(getconf _NPROCESSORS_ONLN)"

%install
runtime=versions/%{version}/runtime
libdir=%{_libdir}/flutter-sfos/%{version}
incdir=%{_includedir}/flutter-sfos/%{version}
execdir=%{_libexecdir}/flutter-sfos/%{version}
cmakedir=%{_libdir}/cmake/flutter-sfos-%{version}
wrapdir=%{_datadir}/flutter-sfos/%{version}/cpp_client_wrapper
sdkdir=%{_datadir}/flutter-sfos/%{version}/sdk
elindir=%{_datadir}/flutter-sfos/%{version}/flutter-elinux
src=$runtime/src/flutter-embedded-linux

mkdir -p %{buildroot}"$libdir" %{buildroot}"$incdir" %{buildroot}"$execdir" %{buildroot}"$cmakedir" %{buildroot}"$wrapdir" %{buildroot}"$sdkdir" %{buildroot}"$elindir"

install -m 755 build-client/flutter-client %{buildroot}"$execdir"/flutter-client
install -m 755 build-so/libflutter_elinux_wayland.so %{buildroot}"$libdir"/libflutter_elinux_wayland.so
install -m 755 "$runtime/engine/libflutter_engine.so" %{buildroot}"$libdir"/libflutter_engine.so
install -m 644 "$runtime/engine/icudtl.dat" %{buildroot}"$libdir"/icudtl.dat
install -m 644 "$runtime/engine/flutter_embedder.h" %{buildroot}"$incdir"/flutter_embedder.h

strip --strip-unneeded %{buildroot}"$libdir"/libflutter_engine.so || true
strip --strip-unneeded %{buildroot}"$execdir"/flutter-client || true
strip --strip-unneeded %{buildroot}"$libdir"/libflutter_elinux_wayland.so || true

patchelf --set-rpath "$libdir" %{buildroot}"$execdir"/flutter-client
patchelf --set-rpath "$libdir" %{buildroot}"$libdir"/libflutter_elinux_wayland.so

cp -a "$src/src/flutter/shell/platform/linux_embedded/public/." %{buildroot}"$incdir"/
mkdir -p %{buildroot}"$incdir"/flutter
if [ -d "$src/src/client_wrapper/include/flutter" ]; then
	cp -a "$src/src/client_wrapper/include/flutter/." %{buildroot}"$incdir"/flutter/
fi
if [ -d "$src/src/flutter/shell/platform/common/client_wrapper/include/flutter" ]; then
	cp -a "$src/src/flutter/shell/platform/common/client_wrapper/include/flutter/." %{buildroot}"$incdir"/flutter/
fi
if [ -d "$src/src/flutter/shell/platform/common/public" ]; then
	cp -a "$src/src/flutter/shell/platform/common/public/." %{buildroot}"$incdir"/
fi

cp -a "$src/src/client_wrapper/." %{buildroot}"$wrapdir"/
cp -a "$src/src/flutter/shell/platform/common/client_wrapper/." %{buildroot}"$wrapdir"/

install -m 755 "$runtime/bin/gen_snapshot" %{buildroot}"$execdir"/gen_snapshot
sed -e "s|@FLUTTER_VERSION@|%{version}|g" \
	template/runtime/flutter-sfos-aot.sh.in \
	> %{buildroot}"$execdir"/flutter-sfos-aot
chmod 755 %{buildroot}"$execdir"/flutter-sfos-aot

cp -a "$runtime/sdk/." %{buildroot}"$sdkdir"/
cp -a "$runtime/flutter-elinux/." %{buildroot}"$elindir"/
rm -rf %{buildroot}"$elindir"/flutter
ln -sfn ../sdk %{buildroot}"$elindir"/flutter
chmod +x %{buildroot}"$elindir"/bin/flutter-elinux

sed -e "s|@VERSION@|%{version}|g" \
	-e "s|@LIBDIR@|$libdir|g" \
	-e "s|@INCLUDEDIR@|$incdir|g" \
	-e "s|@WRAPPERDIR@|$wrapdir|g" \
	-e "s|@SDKDIR@|$sdkdir|g" \
	-e "s|@EXECDIR@|$execdir|g" \
	template/runtime/cmake/flutter-sfos-config.cmake.in \
	> %{buildroot}"$cmakedir"/flutter-sfos-config.cmake

%files
%doc versions/%{version}/runtime/src/flutter-embedded-linux/LICENSE
%dir %{_libdir}/flutter-sfos
%dir %{_libdir}/flutter-sfos/%{version}
%dir %{_libexecdir}/flutter-sfos
%dir %{_libexecdir}/flutter-sfos/%{version}
%{_libdir}/flutter-sfos/%{version}/libflutter_engine.so
%{_libdir}/flutter-sfos/%{version}/libflutter_elinux_wayland.so
%{_libdir}/flutter-sfos/%{version}/icudtl.dat
%{_libexecdir}/flutter-sfos/%{version}/flutter-client

%files devel
%dir %{_includedir}/flutter-sfos
%dir %{_includedir}/flutter-sfos/%{version}
%dir %{_libdir}/cmake/flutter-sfos-%{version}
%{_includedir}/flutter-sfos/%{version}
%{_libdir}/cmake/flutter-sfos-%{version}/flutter-sfos-config.cmake
%dir %{_datadir}/flutter-sfos
%dir %{_datadir}/flutter-sfos/%{version}
%{_datadir}/flutter-sfos/%{version}/cpp_client_wrapper
%{_datadir}/flutter-sfos/%{version}/sdk/
%{_datadir}/flutter-sfos/%{version}/flutter-elinux/
%{_libexecdir}/flutter-sfos/%{version}/gen_snapshot
%{_libexecdir}/flutter-sfos/%{version}/flutter-sfos-aot
