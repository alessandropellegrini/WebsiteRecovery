#!/bin/bash

# Copyright (C) 2015 Alessandro Pellegrini <alessandro@pellegrini.tk>


destination_path="backupi-132" # No trailing slash
domain="roma132.it" # No http, no www, no trailing slash

base_url="http://web.archive.org"


get_initial_pool () {

	echo -e "**** Querying the Wayback Machine for an initial list of archived files\n"

	wget -q ${base_url}/web/*/http://www.${2}/* -O raw-list
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
		wget -q ${base_url}${line} -O mementos
		latest=$(grep -A 3 between mementos | tail -n 1 | sed -n 's/.*href="\([^"]*\)".*/\1/p')
		echo -e "Multiple mementos for $line \n resolved to $latest"
		echo $latest >> $2
		unlink mementos
		sleep 1
	done < $1
}


# Check if a link is internal to Wayback Machine or not. In the latter case, try to extract an internal link from the service
get_remote_link() {

	remote_link=""

	if grep -Gq "\/web\/[0-9a-z_]*\/" <<< "$1"; then
		remote_link=$1
	else
		# Let's query here!
		remote_link=$(wget -qO- ${base_url}/web/*/http://www.${domain}$1/* | grep -A 3 between | tail -n 1 | sed -n 's/.*href="\([^"]*\)".*/\1/p')
	fi

	echo $remote_link
}


find_new_links() {
# $1 is the just dowloaded file


	name=$(basename $1)	
	ext=${name##*.}

	# We just look into html files here
	if [ "$ext" = "htm" ] || [ "$ext" = "html" ] || [ "$ext" = "php" ] || [ "$ext" = "php5" ]; then
		echo -e "**** Scanning for additional unreferenced links\n"
		grep href $1 > tmp-new-link

		while IFS='' read -r line || [[ -n $line ]]; do
			found_link=$(echo $line | sed -n 's/.*href="\([^"]*\)".*/\1/p')

			if [ -z $found_link ]; then
				continue;
			fi
			
			# Discard the link if already present
			if grep -Fxq "$found_link" backup.log; then
				echo "**** $found_link discarded, as it is already present in the list"
			else
				echo -n "**** Checking if $found_link has a remote backup... "
				found_link=$(get_remote_link $found_link)
				if [ -z $found_link ]; then
					echo "no. Cannot add it to the pool of files to download."
				else
					echo "yes. Adding it.\n"
					echo $found_link >> additional
				fi
			fi
		done < tmp-new-link
	fi

	# CSS is another story...
	if [ "$ext" = "css" ]; then
		echo -e "**** Scanning for additional unreferenced links\n"
		grep url $1 > tmp-new-link

		while IFS='' read -r line || [[ -n $line ]]; do
			found_link=$(echo $line | sed -n 's/.*url(\([^"]*\)).*/\1/p')

			if [ -z $found_link ]; then
				continue;
			fi
			
			# Discard the link if already present
			if grep -Fxq "$found_link" backup.log; then
				echo "**** $found_link discarded, as it is already present in the list"
			else
				echo -n "**** Checking if $found_link has a remote backup... "
				found_link=$(get_remote_link $found_link)
				if [ -z $found_link ]; then
					echo "no. Cannot add it to the pool of files to download."
				else
					echo "yes. Adding it.\n"
					echo $found_link >> additional
				fi
			fi
		done < tmp-new-link
	fi
}


download_list() {

	echo -e "**** Downloading the list of files\n"

	cat $1 >> backup.log

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
		wget -q ${base_url}$line -O $destination

		find_new_links $destination

		sleep 1
	done < $1

}


check_complete() {

	echo -e "**** Checking if other files should be downloaded...\n"

	unlink definitive 2> /dev/null
	mv additional list 2> /dev/null

	if [ -s "list" ]; then
		return 1
	fi

	return 0
}


truncate -s 0 backup.log
truncate -s 0 additional


get_initial_pool list $domain

while : ; do
	differentiate list
	add_latest_to_list to-find-out definitive
	download_list definitive
	if check_complete ; then break; fi
done

