#!/bin/bash

dir=$(dirname $0)
[ "$dir" = "." ] && dir=$PWD
echo "Updating pwrtelegram..."
cd $dir
git pull --recurse-submodules; git submodule update --recursive
cd beta
git pull
cd $dir/api
git pull
cd $dir/tg
./configure && make

