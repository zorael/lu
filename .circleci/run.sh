#!/bin/bash

set -uexo pipefail

install_deps() {
    sudo apt update
    sudo apt install -y apt-transport-https

    sudo wget https://netcologne.dl.sourceforge.net/project/d-apt/files/d-apt.list \
        -O /etc/apt/sources.list.d/d-apt.list
    sudo apt update --allow-insecure-repositories

    # fingerprint 0xEBCF975E5BA24D5E
    sudo apt install -y --allow-unauthenticated --reinstall d-apt-keyring
    sudo apt update
    sudo apt install dmd-compiler dub
    #sudo apt install ldc
}

build() {
    time dub test
    time dub test :core

    time dub build -b plain
    time dub build -b plain :core

    time dub build -b release
    time dub build -b release :core
}

# execution start

[[ "$(git branch 2>&1 | grep gh-pages)" ]] && exit 0

case "$1" in
    install-deps)
        install_deps;
        ;;
    build)
        time build dmd;
        #build ldc2;  # 0.14.0; too old
        ;;
    *)
        echo "Unknown command: $1";
        exit 1;
        ;;
esac

exit 0
