#!/usr/bin/env bash

set -x

. /vagrant/setup/tessrc

git clone -b all.la.verse https://github.com/cwf2/tesserae $TESSROOT

perl $TESSROOT/scripts/configure.pl
perl $TESSROOT/scripts/install.pl

cp $TESSROOT/scripts/.tesserae.conf /vagrant/scripts/

perl $TESSROOT/scripts/build-stem-cache.pl
perl $TESSROOT/scripts/patch-stem-cache.pl

perl $TESSROOT/scripts/v3/add_column.pl --parallel $TESSNCORES \
     $TESSROOT/texts/la/*.tess
perl $TESSROOT/scripts/v3/add_col_stem.pl --parallel $TESSNCORES \
     $TESSROOT/texts/la/*.tess
perl $TESSROOT/scripts/v3/corpus-stats.pl --feat stem la

