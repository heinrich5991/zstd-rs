#!/bin/bash
set -e
set -o pipefail

cd zstd
CURRENT=$(git describe --tags)
git fetch -q
TAG=$(git tag -l | grep '^v' | sort | tail -n 1)

if [ $CURRENT != $TAG ]
then
    git checkout $TAG
    cd ..
    git add zstd
    ./update_bindings.sh
    git add src/bindings*.rs

    # Note: You'll need a forked version of cargo-dump that supports metadata
    # For instance https://github.com/gyscos/cargo-dump
    METADATA="zstd.${TAG/v/}"
    cargo bump patch --build $METADATA
    ZSTD_SYS_VERSION=$(cargo read-manifest | jq -r .version | cut -d+ -f1)
    git add Cargo.toml
    cd ..
    cargo add zstd-sys --path ./zstd-sys --vers "=${ZSTD_SYS_VERSION}" --no-default-features
    cargo bump patch --build $METADATA
    ZSTD_SAFE_VERSION=$(cargo read-manifest | jq -r .version | cut -d+ -f1)
    git add Cargo.toml
    cd ..
    cargo add zstd-safe --path ./zstd-safe --vers "=${ZSTD_SAFE_VERSION}" --no-default-features
    cargo bump patch --build $METADATA
    ZSTD_RS_VERSION=$(cargo read-manifest | jq -r .version | cut -d+ -f1)
    git add Cargo.toml

    git commit -m "Update zstd to $TAG"

    # Publish?
    read -p "Publish to crates.io? " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        cd zstd-safe/zstd-sys
        # Need to wait so that the index refreshes.
        cargo publish && sleep 5
        cd ..
        cargo publish && sleep 5
        cd ..
        cargo publish
        git tag $ZSTD_RS_VERSION
    else
        echo "Would have published $ZSTD_RS_VERSION"
    fi

else
    echo "Already using zstd $TAG"
fi

