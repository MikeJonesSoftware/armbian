#!/bin/bash

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# This is the image customization script

# NOTE: It is copied to /tmp directory inside the image
# and executed there inside chroot environment
# so don't reference any files that are not already installed

# NOTE: If you want to transfer files between chroot and host
# userpatches/overlay directory on host is bind-mounted to /tmp/overlay in chroot
# The sd card's root path is accessible via $SDCARD variable.

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

# These are values I added

# CPU Speed value, for both MIN and MAX
if [ -z "$CPUSPEED" ]; then
	CPUSPEED=816000
fi

# The AVAHI/mDNS Discovery data, use default if none specified
# Our zeroconf service information.  This is an XML file that gets copied to /etc/avahi/services/endpoint.service
if [ -z "${SERVICE}" ]; then
	SERVICE="<?xml version=\"1.0\" standalone='no'?><!--*-nxml-*-->\n
<!DOCTYPE service-group SYSTEM \"avahi-service.dtd\">\n
<service-group>\n
\t<name replace-wildcards=\"yes\">%h</name>\n
\t<service>\n
\t\t<type>_iot-device._tcp</type>\n
\t\t<txt-record>nickname=Avahi Generic IoT Device</txt-record>\n
\t\t<port>80</port>\n
\t</service>\n
</service-group>\n"
fi


Main() {
	case $RELEASE in
		noble|jammy|focal)
			UpdateAptGet
			EnablemDNS
			#InstallAVAHI
			DisableIpv6
			InstallCpuFreqUtils
			;;
	esac
}

UpdateAptGet() {
	apt update -y
}

InstallCpuFreqUtils() {
	apt install cpufrequtils -y
	cat > /etc/default/cpufrequtils << EOF
ENABLE=true
MIN_SPEED=$CPUSPEED
MAX_SPEED=$CPUSPEED
GOVERNOR=performance
EOF
	/etc/init.d/cpufrequtils restart
}

EnablemDNS() {
	sed -i '/#MulticastDNS=no/s//MulticastDNS=yes/' /etc/systemd/resolved.conf

	mkdir -p /etc/systemd/dnssd
	cat > /etc/systemd/dnssd/nanopineo.dnssd << EOF
[Service]
Name=new-device
Type=_iot-device._tcp
Port=25000
TxtText="Nickname=SystemD Generic IoT Device" "Provisioned=false"
EOF
	systemctl enable systemd-resolved.service
	systemctl restart systemd-resolved.service
}

InstallAVAHI() {
	apt install -y avahi-daemon libnss-mdns libnss-mymachines
	echo -e ${SERVICE} > /etc/avahi/services/endpoint.service
	chmod 666 /etc/avahi/services/endpoint.service		# ensure the file is writable by user without elevated privileges
}

# Disables ipv6 on the ethernet port and in avahi.  The reason is that an AVAHI timing bug on ipv6 can
# cause a hostname conflict, where the conflict is with itself!
# This leads to the system appending a "-1" (or the next number) after the hostname in order to maintain hostname uniqueness.
# This causes loss of connectivity by the hostname, which is bad.
# Disabling ipv6 eliminates the timing issue, and thus the naming conflict.
# ipv6 is not needed for LAN devices that will never have a public IP address.
# Articles:
#   https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=780981
#   https://superuser.com/questions/575684/how-to-disable-ipv6-on-a-specific-interface-in-linux
# This must be called ***AFTER*** InstallAVAHI() because it modifies an avahi config file
DisableIpv6() {
	# Ensure that ipv6 is disabled in avahi
	sed -i '/^.*use-ipv6=.*/s//use-ipv6=no/' /etc/avahi/avahi-daemon.conf

	# Ensure that ipv6 is disabled on startup
	echo "net.ipv6.conf.all.disable_ipv6=1" > /etc/sysctl.d/00_ipv6_off.conf
	echo "net.ipv6.conf.default.disable_ipv6=1" >> /etc/sysctl.d/00_ipv6_off.conf
	echo "net.ipv6.conf.lo.disable_ipv6=1" >> /etc/sysctl.d/00_ipv6_off.conf

	# For some reason, this is ignored on bootup, and needs to be kickstarted manually on reboot
	# This doesn't work, perhaps it's running too soon?
	crontab -l | { cat; echo '@reboot sudo sysctl -p'; } | crontab -
	crontab -l | { cat; echo '@reboot sudo /etc/init.d/procps restart'; } | crontab -
}

Main "$@"
