#!/bin/bash


destination_path="backup" # No trailing slash


base_url="http://web.archive.org"


download_list() {
	while IFS='' read -r line || [[ -n $line ]]; do
		destination=$(echo $line | sed 's/\/web\/[0-9a-z_]*\///g')
		destination=$(echo $destination | sed 's/http:\/\/www\.studiolegalemartignetti\.it\///g')
		destination=$(echo $destination | sed 's/http:\/\/studiolegalemartignetti\.it\///g')

		# Add initial destination path
		destination="./$destination_path/$destination"

		path=$(dirname $destination)

		name=$(basename $destination)

		#if no extension found, it's likely a folder with missing index.html
		if test "${name%.*}" = "$name"; then
			destination="${destination}/index.html"
			path=$(dirname $destination)
			name=$(basename $destination)
		fi

		echo -e "download $line \n to $destination \n in $path \n basename $name \n"
		mkdir -p $path
		wget ${base_url}$line -O $destination

		sleep 1
	done < $1
}

download_list definitive
