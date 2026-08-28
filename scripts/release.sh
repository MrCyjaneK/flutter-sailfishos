#!/bin/bash

set -x -e

cd "$(dirname "$0")/.."

REPO=mrcyjanek/flutter-sailfishos

function ensure_gh_release() {
    local release=$1
    gh release view $release > /dev/null 2>&1 || gh release create $release --notes="$release"
}

function has_gh_release_asset() {
    local release=$1
    local asset=$2
    gh release view -R "$REPO" "$release" --json assets --jq '.assets[].name' \
        | grep -Fxq "$asset"
}

pushd versions
    for version in 3.*.*; do
        pushd $version
            echo "===> $version"
            source pin.env
            version_full="$version-$RELEASE"
            if [[ ! -f "runtime/rpms/flutter-sfos-$version-$version_full.aarch64.rpm" ]]; then
                continue
            fi
            if [[ ! -f "runtime/rpms/flutter-sfos-$version-devel-$version_full.aarch64.rpm" ]]; then
                continue
            fi

            ensure_gh_release $version_full
            if ! has_gh_release_asset $version_full flutter-sfos-$version-$version_full.aarch64.rpm; then
                gh release upload $version_full runtime/rpms/flutter-sfos-$version-$version_full.aarch64.rpm
            fi
            if ! has_gh_release_asset $version_full flutter-sfos-$version-devel-$version_full.aarch64.rpm; then
                gh release upload $version_full runtime/rpms/flutter-sfos-$version-devel-$version_full.aarch64.rpm
            fi
        popd
    done
popd
