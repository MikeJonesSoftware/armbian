#!/bin/bash

function usage() {
	printf "\nUsage:	$0\n"
	printf "    --config                Name of config to use\n"
	printf "    --root-password         Root user password or passphrase\n"
	printf "    --username              Non-root User account to create (default: security)\n"
	printf "    --user-password         Non-root User password or passphrase\n"
}

while [ $# -gt 0 ]; do
	case "$1" in
		--config=*) CONFIG="${1#*=}" ;;
		--root-password=*) ROOT_PASSWORD="${1#*=}" ;;
		--username=*) NEW_USERNAME="${1#*=}" ;;
		--user-password=*) NEW_USER_PASSWORD="${1#*=}" ;;
	esac
	shift
done

if [ -z "${CONFIG}" ]; then
	echo You must provide the config, e.g. --config=nanopineo-access-control
	usage
	exit 1
fi

if [ -z "${ROOT_PASSWORD}" ]; then
	echo You must provide a new root password, e.g. --root-password="new root password"
	usage
	exit 1
fi

if [ -z "${NEW_USER_PASSWORD}" ]; then
	echo You must provide a new user password, e.g. --user-password="new user password"
	usage
	exit 1
fi

# Call Armbian to build the image
export ROOTPW=${ROOT_PASSWORD}
export NEWUSER=${NEW_USERNAME}
export NEWUSERPW=${NEW_USER_PASSWORD}

if [ "${NEW_USERNAME}" ]; then
	./compile.sh ${CONFIG} ROOTPW=${ROOT_PASSWORD} NEWUSER=${NEW_USERNAME} NEWUSERPW=${NEW_USER_PASSWORD}
else
	./compile.sh ${CONFIG} ROOTPW=${ROOT_PASSWORD} NEWUSERPW=${NEW_USER_PASSWORD}
fi