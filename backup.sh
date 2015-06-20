#!/bin/bash

# Copyright (C) 2015 Alessandro Pellegrini <alessandro@pellegrini.tk>


destination_path="backupi-132" # No trailing slash
domain="roma132.it" # No http, no www, no trailing slash

base_url="http://web.archive.org"


get_initial_pool () {

	echo -e "**** Querying the Wayback Machine for an initial list of archived files\n"

	wget ${base_url}/web/*/http://www.${domain}/* -O raw-list
	cat raw-list | grep href | grep -v link | grep -v Wayback | sed 's/">.*<\/a>//g' | sed 's/<a href="//g' | sed 's/^\t*//g' | sed 's/^ *//g' > $1
	unlink raw-list
}


differentiate() {

	echo -e "**** Separating pages with multiple mementos from those with only one\n"

	grep -v \* $1 > definitive
	grep \* $1 > to-find-out
}


add_latest_to_list() {
# $1 is the to-find-out list, $2 is the definitive list

	echo -e "**** Getting the latest version of files with multiple mementos\n"

	while IFS='' read -r line || [[ -n $line ]]; do
		wget ${base_url}${line} -O mementos
		latest=$(grep -A 3 between mementos | tail -n 1 | sed -n 's/.*href="\([^"]*\)".*/\1/p')
		echo -e "Multiple mementos for $line \n resolved to $latest"
		echo $latest >> $2
		unlink mementos
		sleep 1
	done < $1
}


find_new_links() {
# $1 is the just dowloaded file

	echo -e "**** Scanning for additional unreferenced links\n"

	name=$(basename $1)	
	ext=${name##*.}
	echo "extension in $1 is $ext"

	# We just look into html files here
	if [ "$ext" = "htm" ] || [ "$ext" = "html" ] || [ "$ext" = "php" ] || [ "$ext" = "php5" ]; then
		grep href $1 > tmp-new-link

		while IFS='' read -r line || [[ -n $line ]]; do
			found_link=$(echo $line | sed -n 's/.*href="\([^"]*\)".*/\1/p')

			if [ -z $found_link ]; then
				continue;
			fi
			
			# Discard the link if already present
			if grep -Fxq "$found_link" definitive; then
				echo "**** $found_link discarded, as it is already present in the list"
			else
				echo "**** Adding $found_link to the list of files to download"
				echo $found_link >> additional
			fi
		done < tmp-new-link
	fi

	# CSS is another story...
	if [ "$ext" = "css" ]; then
		grep url $1 > tmp-new-link

		while IFS='' read -r line || [[ -n $line ]]; do
			found_link=$(echo $line | sed -n 's/.*url(\([^"]*\)).*/\1/p')

			if [ -z $found_link ]; then
				continue;
			fi
			
			# Discard the link if already present
			if grep -Fxq "$found_link" definitive; then
				echo "**** $found_link discarded, as it is already present in the list"
			else
				echo "**** Adding $found_link to the list of files to download"
				echo $found_link >> additional
			fi
		done < tmp-new-link
	fi

	exit
	
}


download_list() {

	echo -e "**** Downloading the list of files\n"

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

		find_new_links $destination

		sleep 1
	done < $1
}



echo "" > additional



#get_initial_pool list

#differentiate list

#add_latest_to_list to-find-out definitive

download_list definitive
