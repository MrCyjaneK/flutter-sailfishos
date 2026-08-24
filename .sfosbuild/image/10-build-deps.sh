#!/bin/sh
set -eu

zypper --non-interactive refresh

zypper --non-interactive in --force-resolution \
	clang \
	cmake \
	make \
	pkgconfig \
	binutils \
	linux-glibc-devel \
	git \
	unzip \
	curl \
	'pkgconfig(xkbcommon)' \
	'pkgconfig(wayland-client)' \
	'pkgconfig(wayland-cursor)' \
	'pkgconfig(wayland-egl)' \
	'pkgconfig(wayland-protocols)' \
	'pkgconfig(egl)' \
	'pkgconfig(glesv2)' \
	'pkgconfig(maliit-glib)'

if zypper --non-interactive in --force-resolution patchelf; then
	echo "sfosbuild: patchelf installed"
else
	echo "sfosbuild: patchelf not available"
fi

if [ ! -f /usr/include/linux/input-event-codes.h ]; then
	echo "sfosbuild: installing linux/input-event-codes.h"
	mkdir -p /usr/include/linux
	curl -fsSL -o /usr/include/linux/input-event-codes.h \
		https://raw.githubusercontent.com/torvalds/linux/v6.6/include/uapi/linux/input-event-codes.h
fi
