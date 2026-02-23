

function pre_customize_image__set_nanopineo_values { 
	echo "Configuring nanopineo-specific values..."

}

function post_customize_image__done_with_customization { 
	echo "Done with customization!!!"
}

function post_family_tweaks__preset_configs() {
	display_alert "$BOARD" "preset configs for rootfs" "info"

	# CPU speed
	CPUSPEED=816000

	# DNS-SD service discovery can be found at the bottom of this file

	# Allow the user to set the static IP address, mask, and gateway
	# Default Subnet mask and Gateway are provided if not set by the user
	# DHCP will be used by default
	if [ "${STATIC_IP_ADDRESS}" ]; then
		PRESET_STATIC_IP=1
	else
		PRESET_STATIC_IP=0					# Default to DHCP
		STATIC_IP_ADDRESS='192.168.0.100'	# Placeholder static IP address
	fi
	if [ -z "${STATIC_MASK}" ]; then
		STATIC_MASK='255.255.255.0'
	fi
	if [ -z "${STATIC_GATEWAY}" ]; then
		STATIC_GATEWAY='192.168.0.1'	# Placeholder static gateway
	fi

	# Fixed answers for the initial bootup configuration questions
	# Note that you must create the following environment variables before running compile.sh:
	#    ROOTPW - the new root password
	#    NEWUSER - the new username
	#    NEWUSERPW - the new user password
	cat > "${SDCARD}"/root/.not_logged_in_yet << EOF
	PRESET_NET_CHANGE_DEFAULTS=1
	PRESET_NET_ETHERNET_ENABLED=1
	PRESET_NET_WIFI_ENABLED=0
	PRESET_NET_WIFI_SSID='MySSID'
	PRESET_NET_WIFI_KEY='MyWiFiKEY'
	PRESET_NET_WIFI_COUNTRYCODE='GB'
	PRESET_NET_USE_STATIC=${PRESET_STATIC_IP}
	PRESET_NET_STATIC_IP='${STATIC_IP_ADDRESS}'
	PRESET_NET_STATIC_MASK='${STATIC_MASK}'
	PRESET_NET_STATIC_GATEWAY='${STATIC_GATEWAY}'
	PRESET_NET_STATIC_DNS='8.8.8.8 8.8.4.4'
	PRESET_USER_SHELL=bash
	PRESET_CONNECT_WIRELESS=n
	SET_LANG_BASED_ON_LOCATION=y
	PRESET_LOCALE=en_US.UTF-8
	PRESET_TIMEZONE=Etc/UTC
	PRESET_ROOT_PASSWORD=$ROOTPW
	PRESET_USER_NAME=$NEWUSER
	PRESET_USER_PASSWORD=$NEWUSERPW
	PRESET_DEFAULT_REALNAME=Armbian
EOF

	# /root/provisioning.sh
	# These commands will run automatically on first boot/login
	# Install:
	# 	lm-sensors: reading CPU, etc info
	# 	sysstat: system metrics
	# 	nvi: vi editor
	# 	kbuild: kernel build tools
	# 	devmem2: register I/O poking utility
	# 	cpufrequtils: CPU frequency scaling
	# 	dnssd: mDNS/DNS-SD service discovery

	cat > "${SDCARD}"/root/provisioning.sh << EOF
	echo "Installing lm-sensors..."
	apt install lm-sensors -y -qq
	echo "Installing sysstat..."
	apt install sysstat -y -qq
	echo "Installing vi..."
	apt install nvi -y -qq
	echo "Installing kbuild..."
	apt install -yy kbuild -qq
	echo "Installing devmem2..."
	apt install -y devmem2 -qq

	echo "Installing cpufrequtils..."
	apt install cpufrequtils -y -qq
	cat > /etc/default/cpufrequtils << CPUEOF
ENABLE=true
MIN_SPEED=$CPUSPEED
MAX_SPEED=$CPUSPEED
GOVERNOR=performance
CPUEOF
	/etc/init.d/cpufrequtils restart

	cat > /etc/avahi/services/device.service << AVAHIEOF
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
	<name replace-wildcards="yes">%h</name>
	<service>
		<type>_access-control._tcp</type>
		<txt-record>endpointId=null</txt-record>
		<txt-record>provisioned=false</txt-record>
		<txt-record>assigned=false</txt-record>
		<txt-record>nickname=Door Controller</txt-record>
		<txt-record>type=doorController</txt-record>
		<port>80</port>
	</service>
</service-group>
AVAHIEOF
	systemctl restart avahi-daemon.service

	sed -i '/bin/s//bin:\/home\/$NEWUSER\/bin/' /etc/environment
		echo "$NEWUSER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/00-$NEWUSER
		echo 'Defaults        secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/home/$NEWUSER/bin"' >> /etc/sudoers.d/00-$NEWUSER
EOF

}
