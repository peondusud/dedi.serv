#!/bin/bash
DIR=/tmp/dedi.serv

set -x

rm -rf  /tmp/dedi.serv || true
apt-get update || true
apt-get upgrade -y || true
apt-get install -y git apache2-utils || true
git clone https://github.com/peondusud/dedi.serv.git $DIR
source $DIR/debian.sh
