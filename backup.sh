#!/bin/bash

# Copyright (C) 2015 Alessandro Pellegrini <alessandro@pellegrini.tk>


destination_path="backupi-132" # No trailing slash
domain="roma132.it" # No http, no www, no trailing slash

base_url="http://web.archive.org"


get_initial_pool () {
	wget ${base_url}/web/*/http://www.${domain}/* -O raw-list
	cat raw-list | grep href | grep -v link | grep -v Wayback | sed 's/">.*<\/a>//g' | sed 's/<a href="//g' | sed 's/^\t*//g' | sed 's/^ *//g' > list
}


differentiate() {
	grep -v \* $1 > definitive
	grep \* $1 > to-find-out
}

download_list() {
	while IFS='' read -r line || [[ -n $line ]]; do
		destination=$(echo $line | sed 's/\/web\/[0-9a-z_]*\///g')
		destination=$(echo $destination | sed "s/http:\/\/www\.${domain}\///g")
		destination=$(echo $destination | sed "s/http:\/\/${domain}\///g")

		# Add initial destination path
		destination="./$destination_path/$destination"

		path=$(dirname $destination)

		name=$(basename $destination)

		# If no extension found, it's likely a folder with missing index.html
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





get_initial_pool

differentiate list



#download_list definitive
