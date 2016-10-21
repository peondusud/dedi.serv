#!/bin/bash

fail2ban () {
      # based on https://wiki.meurisse.org/wiki/Fail2Ban
      wget -O- http://neuro.debian.net/lists/jessie.de-m.libre > /etc/apt/sources.list.d/neurodebian.sources.list
      apt-key adv --recv-keys --keyserver hkp://pgp.mit.edu:80 0xA5D32F012649A5A9
      apt-get update
      
      echo "popularity-contest      popularity-contest/participate  boolean false"|  debconf-set-selections
      #echo "popularity-contest      popularity-contest/submiturls   string"|  debconf-set-selections
      apt-get install --no-install-recommends --no-install-suggests -y fail2ban python-pyinotify rsyslog whois

      cp $DIR/fail2ban/jail.local /etc/fail2ban/jail.local

      cp $DIR/fail2ban/jail.d/recidive.conf /etc/fail2ban/jail.d/recidive.conf

      sed -i "s|\(port *=\) ssh|\1 ${SSH_PORT}|" /etc/fail2ban/jail.local
      systemctl start fail2ban
      systemctl enable fail2ban
}

portsentry () {

	echo 'TCP_MODE="atcp"' > /etc/default/portsentry
	echo 'UDP_MODE="audp"' >> /etc/default/portsentry
	
	apt-get install portsentry
	
	sed -i 's|"tcp|"atcp|g' /etc/default/portsentry
	sed -i 's|"udp|"audp|g' /etc/default/portsentry
	
	sed -i  's/^\([^#].*\)/#\1/' /etc/portsentry/portsentry.ignore.static
	
	sed -i 's/\(BLOCK_TCP=\).*/\1"1"/g' /etc/portsentry/portsentry.conf
	sed -i 's/\(BLOCK_UDP=\).*/\1"1"/g' /etc/portsentry/portsentry.conf
	sed -i 's|^\(KILL_ROUTE="\).*$|\1/usr/sbin/nft add element filter blackhole { $TARGET$ }"|' /etc/portsentry/portsentry.conf

	systemctl start portsentry
	systemctl enable portsentry
}

rkhunter () {
	apt-get install -f rkhunter libwww-perl
	
	#vim /etc/rkhunter.conf
	# test conf
	rkhunter -c --sk
	# update
	rkhunter --propupd
	echo 'DPkg::Post-Invoke { "if [ -x /usr/bin/rkhunter ]; then /usr/bin/rkhunter --propupd; fi"; };' > /etc/apt/apt.conf.d/90rkhunter
}

disable_ipv6 () {
	#disable ipv6 support
	sed -i 's|\(GRUB_CMDLINE_LINUX=\)""|\1"ipv6.disable=1"|' /etc/default/grub
	update-grub2
}

hardening_srv () {
	disable_ipv6
	fail2ban
	portsentry
	#rkhunter
}

hardening_srv
