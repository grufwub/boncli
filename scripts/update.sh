#!/bin/bash

readonly BONCLI_BRANCH='master'
readonly BONCLI_URL="https://github.com/grufwub/boncli/raw/$BONCLI_BRANCH/boncli"

printf 'updater script:\n'

BONCLI_PATH=$(which boncli)
if [[ $BONCLI_PATH == '' ]] ; then
	printf '\nexisting boncli not found, exiting...\n'
	exit 1
fi

printf 'downloading...'
download="curl -fLo $BONCLI_PATH $BONCLI_URL --silent"
if [[ -w $BONCLI_PATH ]] ; then
	# path is writeable, sudo not required
	$download
else
	# write permissions for current user not available, trying sudo
	sudo $download
fi

if [[ $? -ne 0 ]] ; then
	printf ' download failed -- boncli failed to update!\n'
	exit 1
else
	printf ' boncli updated successfully!\n'
	exit 0
fi
