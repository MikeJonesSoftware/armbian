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

AVAHI_SERVICE=$(cat <<EOF
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
	<name replace-wildcards="yes">%h</name>
	<service>
		<type>_iot-device._tcp</type>
		<txt-record>nickname=Uninitialized IoT Device</txt-record>
		<port>9000</port>
	</service>
</service-group>
EOF
)

# This file should contain non hardware-specific values that are needed for the image.
# The hardware-specific values will be specified by the ENABLE_EXTENSIONS command-line argument.

Main() {
	case $RELEASE in
		noble|jammy|focal)
			UpdateAptGet
			InstallNetTools
			DisableSystemdResolved
			InstallAvahi
			DisableIpv6
			;;
		bookworm|trixie)
			UpdateAptGet
			InstallNetTools
			DisableSystemdResolved
			InstallAvahi
			DisableIpv6
			;;
	esac
}

UpdateAptGet() {
	apt update -y
}

InstallNetTools() {
	apt install iputils-tracepath iputils-ping mtr-tiny net-tools tcpdump -y -qq
	apt install systemd-timesyncd -y -qq
}

InstallAvahi() {
	apt-get install -y avahi-daemon libnss-mdns libnss-mymachines avahi-utils
	echo "$AVAHI_SERVICE" | tee /etc/avahi/services/device.service > /dev/null
	chmod 666 /etc/avahi/services/endpoint.service		# ensure the file is writable by user without elevated privileges
	
	systemctl enable avahi-daemon.service
	systemctl restart avahi-daemon.service
}

# This uses resolved to enable mDNS.  This is not needed for avahi, but it's a good example of how to enable mDNS.
EnableSystemdResolved() {
	sed -i '/#MulticastDNS=no/s//MulticastDNS=yes/' /etc/systemd/resolved.conf

	mkdir -p /etc/systemd/dnssd
	cat > /etc/systemd/dnssd/iotdevice.dnssd << EOF
[Service]
Name=new-device
Type=_iot-device._tcp
Port=25000
TxtText="Nickname=Uninitialized IoT Device"
EOF

	systemctl enable systemd-resolved.service
	systemctl restart systemd-resolved.service
}

DisableSystemdResolved() {
	# 1. Disable MulticastDNS in resolved
	sudo sed -i 's/^#*MulticastDNS=.*/MulticastDNS=no/' /etc/systemd/resolved.conf

	# 2. Disable LLMNR (prevents port conflicts)
	sudo sed -i 's/^#*LLMNR=.*/LLMNR=no/' /etc/systemd/resolved.conf

	# 3. Ensure the Stub Listener is active for local apps
	sudo sed -i 's/^#*DNSStubListener=.*/DNSStubListener=yes/' /etc/systemd/resolved.conf

	# 4. Restart to apply
	sudo systemctl enable systemd-resolved
	sudo systemctl restart systemd-resolved
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
	sed -i 's/^#*use-ipv6=.*/use-ipv6=no/' /etc/avahi/avahi-daemon.conf
	sed -i 's/^#*publish-a-on-ipv6=.*/publish-a-on-ipv6=no/' /etc/avahi/avahi-daemon.conf

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
