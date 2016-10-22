#!/bin/bash
DIR=/tmp/dedi.serv

rm -rf  /tmp/dedi.serv || true
apt-get update 
apt-get upgrade
apt-get install -y git 
git clone https://github.com/peondusud/dedi.serv.git $DIR
bash -x $DIR/debian.sh
