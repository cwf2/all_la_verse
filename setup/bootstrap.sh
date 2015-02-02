#!/usr/bin/env bash

set -x

#
# install necessary software on vm
#

sudo apt-get update

sudo apt-get install -y \
	git                 \
	screen              \
	vim                 \
	htop                \
	perl-doc            \
	libfile-copy-recursive-perl \
	libparallel-forkmanager-perl \
	liblingua-stem-perl \
	libdbd-sqlite3-perl \
	libjson-perl        \
	libxml-libxml-perl  \
   r-base-core

sudo -u vagrant cp /vagrant/setup/vimrc /home/vagrant/.vimrc
sudo -u vagrant cp /vagrant/setup/gitconfig /home/vagrant/.gitconfig

