#!/bin/bash

function usage() {
	printf "\nUsage:	$0\n"
	printf "    --board                 Name of board to target the image\n"
	printf "    --root-pw               New root password or passphrase\n"
	printf "    --new-user              New User account to login to\n"
	printf "    --new-user-pw           New User password or passphrase\n"
}

while [ $# -gt 0 ]; do
	case "$1" in
		--board=*) BOARD="${1#*=}" ;;
		--root-pw=*) ROOTPW="${1#*=}" ;;
		--new-user=*) NEWUSER="${1#*=}" ;;
		--new-user-pw=*) NEWUSERPW="${1#*=}" ;;
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

if [ -z "${NEWUSER}" ]; then
	echo You must provide a new username, e.g. --new-user="username"
	usage
	exit 1
fi

if [ -z "${NEWUSERPW}" ]; then
	echo You must provide a new user password, e.g. --new-user-pw="new user password"
	usage
	exit 1
fi

# Call Armbian to build the image
./compile.sh ${BOARD} ROOTPW=${ROOTPW} NEWUSER=${NEWUSER} NEWUSERPW=${NEWUSERPW}
