#!/bin/sh

set -exu

# Add your additional provisioning here for custom VM images.
cd /tmp

git clone --branch v0.1.0 https://codeberg.org/4neko/freyashell.git

cd ./freyashell

cargo build --release

cp ./target/release/freyashell /usr/local/bin/freyashell
