#!/usr/bin/env bash

set -x

cd /vagrant/tesserae

perl scripts/configure.pl
perl scripts/install.pl

perl scripts/v3/build-stem-cache.pl
perl scripts/v3/patch-stem-cache.pl

perl scripts/v3/add_column.pl --parallel 2 texts/la/*
perl scripts/v3/add_col_stem.pl --parallel 2 texts/la/*
perl scripts/v3/corpus-stats.pl --feat stem la

