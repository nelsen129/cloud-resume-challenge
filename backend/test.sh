#!/bin/bash

mkdir -p out
rm -rf out/*

curr_dir=$(pwd)
for file_name in $(find . -name "api_info.txt")
do
    cd $(dirname $file_name)
    go get .
    go test . -cover
    cd $curr_dir
done
