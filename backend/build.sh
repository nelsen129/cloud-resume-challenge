#!/bin/bash

mkdir -p out
rm -rf out/*

curr_dir=$(pwd)
for file_name in $(find . -name "api_info.txt")
do
    cat $file_name >> out/api_info.txt
    cd $(dirname $file_name)
    go get .
    GOOS=linux GOARCH=amd64 go build main.go
    zip $curr_dir/out/$(cat "api_info.txt" | awk '{print $3}') main
    rm main
    cd $curr_dir
done

touch out/api_info.txt

api_count=$(wc -l < out/api_info.txt | awk '{print $1}')
zip_count=$(find out/ -name "*.zip" | wc -l)

if [ $api_count -ne $zip_count ]
then
    echo "Error: unexpected number of files. Check that there is no misconfigured api_info.txt" >&2
    exit 1
fi
