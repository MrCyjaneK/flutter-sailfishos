#!/bin/sh
set -eu

ssu ar cyanek-sfos 'https://sfos.repo.mrcyjanek.net/%(arch)/' 2>/dev/null || true
rpm --import https://sfos.repo.mrcyjanek.net/RPM-GPG-KEY-cyanek
ssu ur
zypper --non-interactive --gpg-auto-import-keys refresh
