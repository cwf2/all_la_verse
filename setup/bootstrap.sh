#!/usr/bin/env bash

set -x

#
# install necessary software on vm
#

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

#
# install Tesserae
#

sudo -u vagrant /vagrant/setup/setup.tesserae.sh


#
# the la_verse experiment
#

cd /vagrant

# generate index of all texts from Tesserae metadata
sudo -u vagrant /vagrant/scripts/nodelist.pl

# enque all the searches, then run them
sudo -u vagrant /vagrant/scripts/all_la_verse.pl

# read the Tesserae results and extract just the scores
sudo -u vagrant /vagrant/scripts/extract_scores.pl

