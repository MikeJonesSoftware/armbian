#!/bin/bash

function usage() {
	printf "\nUsage:	$0\n"
	printf "    --board                 Name of board to target the image\n"
	printf "    --root-password         Root user password or passphrase\n"
	printf "    --username              Non-root User account to create (default: security)\n"
	printf "    --user-password         Non-root User password or passphrase\n"
}

while [ $# -gt 0 ]; do
	case "$1" in
		--board=*) BOARD="${1#*=}" ;;
		--root-password=*) ROOTPW="${1#*=}" ;;
		--username=*) NEWUSER="${1#*=}" ;;
		--user-password=*) NEWUSERPW="${1#*=}" ;;
	esac
	shift
done

if [ -z "${BOARD}" ]; then
	echo You must provide the target board hardware, e.g. --board=nanopineo
	usage
	exit 1
fi

if [ -z "${ROOTPW}" ]; then
	echo You must provide a new root password, e.g. --rootpw="new root password"
	usage
	exit 1
fi

# Default username to 'security' if not provided
if [ -z "${NEWUSER}" ]; then
	NEWUSER=security
fi

if [ -z "${NEWUSERPW}" ]; then
	echo You must provide a new user password, e.g. --new-user-pw="new user password"
	usage
	exit 1
fi

# Call Armbian to build the image
./compile.sh ${BOARD} ROOTPW=${ROOTPW} NEWUSER=${NEWUSER} NEWUSERPW=${NEWUSERPW}
