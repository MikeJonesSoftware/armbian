

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

	# This command often returns enp0s1, which means 'Ethernet controller 0' PCI Slot 1
	# This is not helpful for us, as the real ethernet interface gets named something else.
	# On the NanoPi NEO, the real ethernet interface is called 'end0'.
	#INTERFACE_NAME=$(ip route show default | awk '{print $5}')

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

	# Install apps before modifying the network configuration, in case the network change alters the IP address.
	echo "Installing vi..."
	apt install nvi -y -qq

	# Create a bash script that requests a refresh on the _iot-device._tcp service type.
	# This is used to prevent the switch from pruning the _iot-device._tcp service type
	cat > /usr/local/bin/mdns-pulse.sh << PULSEEOF
#!/bin/bash
# Force a fresh process environment to trigger a real wire-level mDNS probe
#/bin/sh -c "/usr/bin/avahi-browse -rt _iot-device._tcp --terminate" > /dev/null 2>&1
#/bin/sh -c "/usr/bin/avahi-resolve -n $(hostname).local -4" > /dev/null 2>&1

# Use a timestamp to ensure the TXT record is unique every 90 seconds
NONCE=$(date +%s)

# Use -c to allow the shell to handle the background process and PID
/bin/sh -c "avahi-publish -s 'Heartbeat-$(hostname)' _heartbeat._tcp 9999 'v=$NONCE' & sleep 2; kill \$!"
PULSEEOF

	chmod +x /usr/local/bin/mdns-pulse.sh

	# Create a systemd service that executes the mdns-pulse.sh script
	cat > /etc/systemd/system/mdns-pulse.service << PULSESERVICEEOF
[Unit]
Description=Periodic mDNS Pulse to prevent Switch Pruning
After=network.target avahi-daemon.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/mdns-pulse.sh
#CPUSchedulingPolicy=fifo
#CPUSchedulingPriority=99

[Install]
WantedBy=multi-user.target
PULSESERVICEEOF

	# Create a systemd timer that executes the mdns-pulse.service every 90 seconds
	cat > /etc/systemd/system/mdns-pulse.timer << PULSETIMEREOF
[Unit]
Description=Run mDNS Pulse every 90 seconds

[Timer]
OnBootSec=1min
OnUnitActiveSec=90s
AccuracySec=1s

[Install]
WantedBy=timers.target
PULSETIMEREOF

	systemctl daemon-reload
	systemctl enable --now mdns-pulse.timer

	# --- [server] section ---
	sed -i "s/^#\?host-name=.*/host-name=${BOARD}/" /etc/avahi/avahi-daemon.conf
	sed -i "s/^#\?domain-name=.*/domain-name=local/" /etc/avahi/avahi-daemon.conf
	sed -i "s/^#\?allow-interfaces=.*/allow-interfaces=\${ETHERNET_INTERFACE}/" /etc/avahi/avahi-daemon.conf
	sed -i "s/^#\?check-response-ttl=.*/check-response-ttl=no/" /etc/avahi/avahi-daemon.conf
	sed -i "s/^#\?use-iff-running=.*/use-iff-running=no/" /etc/avahi/avahi-daemon.conf
	sed -i "s/^#\?cache-entries-max=.*/cache-entries-max=0/" /etc/avahi/avahi-daemon.conf
	sed -i "s/^ratelimit-interval-usec=.*/ratelimit-interval-usec=0/" /etc/avahi/avahi-daemon.conf

	# --- [wide-area] section ---
	sed -i "s/^enable-wide-area=.*/enable-wide-area=no/" /etc/avahi/avahi-daemon.conf

	# --- [publish] section ---
	sed -i "s/^#\?publish-addresses=.*/publish-addresses=yes/" /etc/avahi/avahi-daemon.conf
	sed -i "s/^publish-hinfo=.*/publish-hinfo=yes/" /etc/avahi/avahi-daemon.conf
	sed -i "s/^#\?publish-domain=.*/publish-domain=yes/" /etc/avahi/avahi-daemon.conf
	sed -i "s/^publish-a-on-ipv6=.*/publish-a-on-ipv6=yes/" /etc/avahi/avahi-daemon.conf
	sed -i "s/^#\?publish-aaaa-on-ipv4=.*/publish-aaaa-on-ipv4=yes/" /etc/avahi/avahi-daemon.conf
	sed -i "s/^#\?disable-publishing=.*/disable-publishing=no/" /etc/avahi/avahi-daemon.conf
	sed -i "s/^#\?disable-user-service-publishing=.*/disable-user-service-publishing=no/" /etc/avahi/avahi-daemon.conf
	sed -i "s/^#\?add-service-cookie=.*/add-service-cookie=yes/" /etc/avahi/avahi-daemon.conf

	# --- [rlimits] section ---
	sed -i "s/^#\?rlimit-data=.*/rlimit-data=33554432/" /etc/avahi/avahi-daemon.conf
	sed -i "s/^#\?rlimit-nproc=.*/rlimit-nproc=10/" /etc/avahi/avahi-daemon.conf
	sed -i "s/^#\?rlimit-nofile=.*/rlimit-nofile=1024/" /etc/avahi/avahi-daemon.conf
	sed -i "s/^#\?rlimit-core=.*/rlimit-core=0/"
	sed -i "s/^#\?rlimit-stack=.*/rlimit-stack=8388608/" /etc/avahi/avahi-daemon.conf
	sed -i "s/^#\?rlimit-fsize=.*/rlimit-fsize=0/" /etc/avahi/avahi-daemon.conf

	cat > /etc/avahi/services/device.service << AVAHIEOF
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
	<name replace-wildcards="yes">%h</name>
	<service>
		<type>_iot-device._tcp</type>
		<port>8080</port>
		<txt-record>nickname=Initialized NanoPi NEO OpenMediaVault</txt-record>
	</service>
</service-group>
AVAHIEOF
	systemctl restart avahi-daemon.service


	echo "Configuring user sudo rights..."
	sed -i '/bin/s//bin:\/home\/$NEWUSER\/bin/' /etc/environment
		echo "$NEWUSER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/00-$NEWUSER
		echo 'Defaults        secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/home/$NEWUSER/bin"' >> /etc/sudoers.d/00-$NEWUSER
EOF


	# Add a config setting to /boot/armbianEnv.txt to allocate contiguous memory for video decoding
	echo "Configuring video decoding memory buffer alignment..."
	cat >> "${SDCARD}"/boot/armbianEnv.txt << EOF
extraargs=cma=256M
EOF

}
