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
	libxml-libxml-perl

sudo -u vagrant cp /vagrant/setup/vimrc /home/vagrant/.vimrc
sudo -u vagrant cp /vagrant/setup/gitconfig /home/vagrant/.gitconfig

sudo -u vagrant /vagrant/setup/setup.tesserae.sh

sudo -u vagrant /vagrant/scripts/nodelist.pl

sudo -u vagrant /vagrant/scripts/all_la_verse.pl --parallel 0

sudo -u vagrant /vagrant/scripts/extract_scores.pl
