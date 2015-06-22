# WebsiteRecovery

WebsiteRecovery is a simple bash script which attempts to create a clone of the latest snapshot of a website on the Internet Archive's Wayback Machine.

It can be used, for example, to recover a website which was lost by some service provider or which was vandalized by some random hacker.

It was born in one night, when the known Warrick tool was failing to recover a website I needed.
The script is far from being perfect, there are a lot of konwn issues, and it can be optimized both in terms of requests to the Wayback Machine and of checks done.

## Features

The script currently does the following:

* It revtrieves all the available pages on the Wayback Machine for a given url
* Downloads all the pages, at their latest version
* Scans the downloaded pages looking for files which were not listed in the Wayback Machine (images, scripts, css styles, ...) and attempts to download their latest version
* Discard links which "leave" the website (e.g., facebook links, ...)
* Removes all links used for navigation internal to the Wayback Machine
* Converts all links to relative, allowing for local browsing (limited to html, php, and css files)

## Possible Enhancements

The script does not allow to specify a "closest date" according to which to download files: only the latest version of all files is downloaded. Anyhow, in case of vandalization of a website, it's likely that all the files are still present on the Wayback Machine, so that a backup copy could be obtained with minimal manual effort.

There is no possibility to use flags to skip execution steps: everything listed above is always executed.

## How to use

Open `backup.sh`. At the top there are the following variables:

* `destination_path`: set it to the name of a subfolder where to store the downloaded files
* `domain`: set it to the url which you want to recover, without initial http:// and trailing /.

Then simply run `backup.sh`. Several support files are created during the execution. You can delete all of them safely at any point. Only keep `backup.log` if you plan to stop the execution of the script and restart it later, as this can speed a bit the resume of the execution (although the downloaded files are always checked to determine whether a given file was already downloaded or not).
