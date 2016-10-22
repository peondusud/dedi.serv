#!/bin/bash
DIR=/tmp/dedi.serv

set -x

rm -rf  /tmp/dedi.serv || true
apt-get update 
apt-get upgrade
apt-get install -y git 
git clone https://github.com/peondusud/dedi.serv.git $DIR
source $DIR/debian.sh
