

function pre_customize_image__set_default_username { 
	echo "Configuring nanopineo-specific values..."


	# Our zeroconf service information.  This is an XML file that gets copied to
	# /etc/avahi/services/endpoint.service
	export SERVICE="<?xml version=\"1.0\" standalone='no'?><!--*-nxml-*-->\n
<!DOCTYPE service-group SYSTEM \"avahi-service.dtd\">\n
<service-group>\n
\t<name replace-wildcards=\"yes\">%h</name>\n
\t<service>\n
\t\t<type>_iot-device._tcp</type>\n
\t\t<txt-record>nickname=Custom Device</txt-record>\n
\t\t<port>80</port>\n
\t</service>\n
</service-group>\n"

}

function post_customize_image__done_with_customization { 
	echo "Done with customization!!!"
}

function post_family_tweaks__preset_configs() {
	display_alert "$BOARD" "preset configs for rootfs" "info"

	ROOTPW=nerdherd
	NEWUSER=doofus
	NEWUSERPW=nerdherd

	cat > "${SDCARD}"/root/.not_logged_in_yet << EOF
	PRESET_NET_CHANGE_DEFAULTS=1
	PRESET_NET_ETHERNET_ENABLED=1
	PRESET_NET_WIFI_ENABLED=0
	PRESET_NET_WIFI_SSID='MySSID'
	PRESET_NET_WIFI_KEY='MyWiFiKEY'
	PRESET_NET_WIFI_COUNTRYCODE='GB'
	PRESET_NET_USE_STATIC=0
	PRESET_NET_STATIC_IP='192.168.0.100'
	PRESET_NET_STATIC_MASK='255.255.255.0'
	PRESET_NET_STATIC_GATEWAY='192.168.0.1'
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

	sed -i '/bin/s//bin:\/home\/'"$NEWUSER"'\/bin/' /etc/environment
        echo "$NEWUSER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/00-$NEWUSER
        echo 'Defaults        secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/home/'"$NEWUSER"'/bin"' >> /etc/sudoers.d/00-$NEWUSER
EOF
}
