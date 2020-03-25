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

    curl -fsS --retry 3 https://dlang.org/install.sh | bash -s ldc
}

build() {
    time dub test --compiler=$1

    time dub build --compiler=$1 -b plain
    time dub build --compiler=$1 -b plain :core
    time dub build --compiler=$1 -b plain :conv
    time dub build --compiler=$1 -b plain :meld
    time dub build --compiler=$1 -b plain :string
    time dub build --compiler=$1 -b plain :traits
    time dub build --compiler=$1 -b plain :uda
    time dub build --compiler=$1 -b plain :common
    time dub build --compiler=$1 -b plain :json
    time dub build --compiler=$1 -b plain :net
    time dub build --compiler=$1 -b plain :objmanip
    time dub build --compiler=$1 -b plain :serialisation
    time dub build --compiler=$1 -b plain :deltastrings

    time dub build --compiler=$1 -b release
    time dub build --compiler=$1 -b release :core
    time dub build --compiler=$1 -b release :conv
    time dub build --compiler=$1 -b release :meld
    time dub build --compiler=$1 -b release :string
    time dub build --compiler=$1 -b release :traits
    time dub build --compiler=$1 -b release :uda
    time dub build --compiler=$1 -b release :common
    time dub build --compiler=$1 -b release :json
    time dub build --compiler=$1 -b release :net
    time dub build --compiler=$1 -b release :objmanip
    time dub build --compiler=$1 -b release :serialisation
    time dub build --compiler=$1 -b release :deltastrings
}

# execution start

[[ "$(git branch 2>&1 | grep gh-pages)" ]] && exit 0

case "$1" in
    install-deps)
        install_deps

        dub --version
        dmd --version
        ldc --version
        ;;
    build)
        time build dmd
        time build ldc
        ;;
    *)
        echo "Unknown command: $1"
        exit 1
        ;;
esac

exit 0
