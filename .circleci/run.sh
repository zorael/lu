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
    sudo apt install -y --allow-unauthenticated dmd-compiler dub

    #curl -fsS --retry 3 https://dlang.org/install.sh | bash -s ldc
}

build() {
    time dub test  --compiler=$1
    time dub build --compiler=$1 -b debug
    time dub build --compiler=$1 -b plain
    time dub build --compiler=$1 -b release
}

# execution start

[[ "$(git branch 2>&1 | grep gh-pages)" ]] && exit 0

case "$1" in
    install-deps)
        install_deps

        dub --version
        dmd --version
        #ldc --version
        ;;
    build)
        time build dmd
        #time build ldc
        ;;
    *)
        echo "Unknown command: $1"
        exit 1
        ;;
esac

exit 0
