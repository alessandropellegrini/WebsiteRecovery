#!/bin/bash

# Copyright (C) 2015 Alessandro Pellegrini <alessandro@pellegrini.tk>


destination_path="martignetti" # No trailing slash
domain="studiolegalemartignetti.it" # No http, no www, no trailing slash


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

		# If file is already downloaded, skip this

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

		if [ -f "$destination" ]; then
			continue
		fi

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



store_new_links() {

	name=$(basename $1)	
	ext=${name##*.}

	if [ "$ext" = "htm" ] || [ "$ext" = "html" ] || [ "$ext" = "php" ] || [ "$ext" = "php5" ] || [ "$ext" = "css" ]; then
		echo -e "**** Scanning for additional unreferenced links in $1\n"
		cat $1 | ./list_urls.sed > tmp-new-link.tmp
		cat tmp-new-link.tmp | sort | uniq >> tmp-new-link
		cat tmp-new-link | sort | uniq > tmp-new-link.tmp
		mv tmp-new-link.tmp tmp-new-link
	fi
}

find_new_links() {
# $1 is the just-dowloaded file

	echo -e "**** Scanning for additional unreferenced links\n"

	while IFS='' read -r found_link || [[ -n $found_link ]]; do

		if [ -z $found_link ] ||  [[ ${found_link:0:1} == "#" ]]; then
			echo "**** $found_link does not appear to be valid"
		else

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
				sleep 1
			fi
		fi
	done < tmp-new-link
	truncate -s 0 tmp-new-link
}


make_links_local() {
# $1 is the just-downloaded file
	name=$(basename $1)	
	ext=${name##*.}

	# We just look into html and css files
	if [ "$ext" = "htm" ] || [ "$ext" = "html" ] || [ "$ext" = "php" ] || [ "$ext" = "php5" ] || [ "$ext" = "css" ]; then

		echo -e "**** Converting absolute links to relative links in $1"
	 	sed -i "s/http:\/\/www.${domain}\//\.\//g" $1
		sed -i "s/http:\/\/${domain}\//\.\//g" $1
		sed -i "s/${domain}\//\.\//g" $1
		sed -i "s/\/web\/[0-9a-z_]*\///g" $1
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

		if grep -q ${domain} <<< $line; then

			# Check if we have already downloaded this file
			if [ -f "$destination" ]; then
				continue;
			fi

			echo -e "download $line \n to $destination \n in $path \n basename $name \n"
			mkdir -p $path
			wget -q ${base_url}$line -O $destination

			store_new_links $destination
			make_links_local $destination

			sleep 1
		else
			echo -e "skipping $line \n it appears to be an external link\n"
		fi
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
truncate -s 0 list


get_initial_pool list $domain

while : ; do
	differentiate list
	add_latest_to_list to-find-out definitive
	download_list definitive
	find_new_links
	if check_complete ; then break; fi
done

unlink list
