#!/bin/bash

USERNAME="peon"
SSH_PORT=22222
MYDOMAIN=peon.peon.org

SHELL_PATH=$(dirname $0)

set -euf -o pipefail

BUILD_DEPS="git subversion automake libtool libcppunit-dev build-essential pkg-config libssl-dev libcurl4-openssl-dev libsigc++-2.0-dev libncurses5-dev"
NGINX_DEPS="zlib1g-dev libpcre3 libpcre3-dev unzip apache2-utils php7.0 php7.0-cli php7.0-fpm php7.0-curl php7.0-geoip php7.0-xml php7.0-mbstring php7.0-zip php7.0-json php7.0-gd php7.0-mcrypt php7.0-msgpack php7.0-memcached php7.0-intl php7.0-sqlite3"
TORRENT_DEPS="libncursesw5 screen curl unzip unrar rar zip bzip2 ffmpeg buildtorrent mediainfo"
PLEX_DEPS="alsa alsa-oss oss-compat libasound2-plugins"

settings_warning () {
	echo "USERNAME =  ${USERNAME}"
	echo "SSH_PORT = ${SSH_PORT}"		
	echo "MYDOMAIN = ${MYDOMAIN}"
	echo -n "Is this a good (y/n)? "
	read answer
	if echo "$answer" | grep -iq "^n" ;then
    	exit
	fi
}

install_req () {
      apt-get update
      apt-get -y dist-upgrade

      apt-get install -y htop curl unzip git subversion nano vim zsh 
      apt-get remove -y bind9
      #apt-get --purge autoremove 
}

new_user_config () {
      apt-get install -y sudo
      if (( $(id -u user > /dev/null 2>&1; echo $?) == 0 )); then
            echo "Add new user: ${USERNAME}"
            useradd -ms /bin/zsh "${USERNAME}"
            passwd "${USERNAME}"
      fi
      echo "Add ${USERNAME} to sudoers"
      echo "${USERNAME}    ALL=(ALL:ALL) ALL" >> /etc/sudoers
}

ssh_config () {

      echo "setting SSH config"
      #ssh server conf
      sed -i "s|\(Port\).*$|\1 ${SSH_PORT}|" /etc/ssh/sshd_config
      sed -i "s|\(PermitRootLogin\).*$|\1 no|" /etc/ssh/sshd_config
      sed -i "s|\(X11Forwarding\).*$|\1 no|" /etc/ssh/sshd_config
      echo "AllowUsers ${USERNAME}" >> /etc/ssh/sshd_config
      echo "AddressFamily inet # IPv4 only" >> /etc/ssh/sshd_config

      echo "On your desktop, to use certificat:"
      echo "ssh-copy-id -i ~/.ssh/id_rsa.pub ${USERNAME}@MYDOMAIN"

      echo "Once done press [ENTER] to restart ssh service"
      read -n 1 -s
      systemctl restart ssh.service
}


sysctl_config () {
      wget https://raw.githubusercontent.com/peondusud/dedi.serv/master/sysctl.d/local.conf -O /etc/sysctl.d/local.conf
      #mv sysctl.d/local.conf  /etc/sysctl.d/local.conf

      # reload sysctl
      echo "reload sysctl config"
      sysctl --system
}


nftables_config () {
	find /etc/apt/ -name *.list | xargs cat | grep  ^[[:space:]]*deb | grep -v deb-src | grep "jessie-backports main"
	if [[ $? -eq 1 ]] ; then
		echo "deb http://ftp.debian.org/debian jessie-backports main" >> /etc/apt/sources.list
	fi
	apt-get update
	apt-get install -y nftables ulogd2 ulogd2-sqlite3 ulogd2-pcap ulogd2-json
	#nft flush table filter

	mkdir -p /etc/nftables
	wget https://raw.githubusercontent.com/peondusud/dedi.serv/master/nftables/fw.ruleset -O /etc/nftables/fw.ruleset
	sed -i "s|\${SSH_PORT}|${SSH_PORT}|" /etc/nftables/fw.ruleset

	# load ruleset from file
	nft -f /etc/nftables/fw.ruleset

	# display full rules
	nft list ruleset

	wget https://raw.githubusercontent.com/peondusud/dedi.serv/master/fail2ban/action.d/nftables-common.local -O /etc/fail2ban/action.d/nftables-common.local
	#mv fail2ban/action.d/nftables-common.local /etc/fail2ban/action.d/nftables-common.local

	## check is xt_LOG module exists
	grep xt_LOG /lib/modules/$(uname -r)/modules.dep
	## check is nfnetlink_log module exists
	grep nfnetlink_log /lib/modules/$(uname -r)/modules.dep

	modprobe xt_LOG nfnetlink_log
	# xt_LOG is aliased to ipt_LOG and ip6t_LOG

      ## check netfilter log config
      cat /proc/net/netfilter/nf_log  
      ## 2=IPv4, 4=Novell IPX, 10=IPv6, ...
      #define AF_UNSPEC	  0
      #define AF_UNIX		  1	/* Unix domain sockets 		*/
      #define AF_INET		  2	/* Internet IP Protocol 	*/
      #define AF_AX25		  3	/* Amateur Radio AX.25 		*/
      #define AF_IPX		  4	/* Novell IPX 			*/
      #define AF_APPLETALK  5	/* Appletalk DDP 		*/
      #define AF_NETROM	  6	/* Amateur radio NetROM 	*/
      #define AF_BRIDGE     7	/* Multiprotocol bridge 	*/
      #define AF_AAL5		  8	/* Reserved for Werner's ATM 	*/
      #define AF_X25		  9	/* Reserved for X.25 project 	*/
      #define AF_INET6     10	/* IP version 6			*/
      #define AF_MAX       12	/* For now.. */

      # use ipt_LOG for IPv4
      #echo "ipt_LOG" > /proc/sys/net/netfilter/nf_log/2

      echo "nfnetlink_log" > /proc/sys/net/netfilter/nf_log/2
      #echo "255" > /proc/sys/net/netfilter/nf_conntrack_log_invalid

      # Ulogd setup
      # use syslog
      #sed -i "s|^#\(.*log3.*SYSLOG\)|\1|" /etc/ulogd.conf
      
      
      nft  insert rule  filter input iif eth0 tcp dport { 50000} accept
}



docker_install () {
      apt-get install -y apt-transport-https ca-certificates
      apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
      echo "deb https://apt.dockerproject.org/repo debian-jessie main" > /etc/apt/sources.list.d/docker.list
      apt-get update
      apt-get install -y docker-engine
      sudo groupadd docker
      gpasswd -a ${USERNAME} docker
      service docker restart
      docker pull debian:jessie
      docker pull alpine:latest

      # docker compose
      curl -L https://github.com/docker/compose/releases/download/1.8.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
      chmod +x /usr/local/bin/docker-compose
}


install_basics () {
      install_req
      new_user_config
      ssh_config
      sysctl_config
      nftables_config
}

add_repo () {
	sed -ri 's/main$/main contrib non-free/g' /etc/apt/sources.list

	find /etc/apt/ -name *.list | xargs cat | grep  ^[[:space:]]*deb | grep -v deb-src | grep "nginx.org/packages/debian/ jessie nginx"
	if [[ $? -eq 1 ]] ; then
		echo -e "\n#Depot Nginx\ndeb http://nginx.org/packages/debian/ jessie nginx" >> /etc/apt/sources.list
	fi
	find /etc/apt/ -name *.list | xargs cat | grep  ^[[:space:]]*deb | grep -v deb-src | grep "packages.dotdeb.org jessie all"
	if [[ $? -eq 1 ]] ; then
		echo -e "\n#Depot Dotdeb\ndeb http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list
	fi
	find /etc/apt/ -name *.list | xargs cat | grep  ^[[:space:]]*deb | grep -v deb-src | grep "www.deb-multimedia.org jessie main non-free"
	if [[ $? -eq 1 ]] ; then
		echo -e "\n#Depot Multimedia\ndeb http://www.deb-multimedia.org jessie main non-free" >> /etc/apt/sources.list
	fi
	find /etc/apt/ -name *.list | xargs cat | grep  ^[[:space:]]*deb | grep -v deb-src | grep "jessie-backports main contrib non-free"
	if [[ $? -eq 1 ]] ; then	
	echo "deb http://httpredir.debian.org/debian jessie-backports main contrib non-free" >> /etc/apt/sources.list
	fi
	

	curl -s http://www.dotdeb.org/dotdeb.gpg | apt-key add -
	apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62
	#apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $nginx_pubkey # remove NO_PUBKEY
	apt-get update
	apt-get install -y --force-yes deb-multimedia-keyring
	apt-get update
	}

xmlrpc_build () {
      cd /tmp
      svn checkout http://svn.code.sf.net/p/xmlrpc-c/code/stable xmlrpc-c
      cd xmlrpc-c/
      ./configure --disable-cplusplus
      make -j$(nproc)
      make install
      ldconfig
}

libtorrent_build () {
	cd /tmp
	git clone https://github.com/rakshasa/libtorrent.git
	cd libtorrent
	git checkout 0.13.6
	./autogen.sh
	./configure --with-posix-fallocate
	make -j$(nproc)
	make install
	ldconfig
}

rtorrent_build () {
	cd /tmp
	git clone https://github.com/rakshasa/rtorrent.git
	cd rtorrent
	git checkout 0.9.6
	./autogen.sh
	./configure --with-xmlrpc-c --with-ncurses
	make
	make install
	ldconfig
}

rtorrent_config () {
	rtorrent_user="${USERNAME}"
	
	mkdir -p "/home/${rtorrent_user}/rtorrent"/{.session,download,complete,log,watch/load,watch/start}
	wget https://raw.githubusercontent.com/peondusud/dedi.serv/master/rtorrent/.rtorrent.rc -O /home/${rtorrent_user}/.rtorrent.rc
	sed -i "s/<username>/${rtorrent_user}/g" /home/${rtorrent_user}/.rtorrent.rc
	chown -R ${rtorrent_user}:${rtorrent_user} /home/${rtorrent_user}/{*,.*}
	
	wget https://raw.githubusercontent.com/peondusud/dedi.serv/master/systemd/system/rtorrent%40.service -O /etc/systemd/system/rtorrent\@.service
	systemctl start rtorrent@${rtorrent_user}
	systemctl enable rtorrent@${rtorrent_user}
}

rutorrent_install () {
	mkdir -p /var/www
	cd /var/www
	git clone https://github.com/Novik/ruTorrent.git rutorrent
	cp /var/www/rutorrent/images/favicon.ico /var/www/rutorrent/
	cd /var/www/rutorrent/plugins/
	git clone https://github.com/xombiemp/rutorrentMobile.git mobile
	cd /var/www/rutorrent/plugins/
	git clone https://github.com/nelu/rutorrent-thirdparty-plugins
	mv rutorrent-thirdparty-plugins/* .
	rm -rf rutorrent-thirdparty-plugins	
	chown -R www-data:www-data /var/www/rutorrent
}


rutorrent_conf () {
	sed -i "s|\(\"php\".*\)'',|\1'$(which php)',|" /var/www/rutorrent/conf/config.php
	sed -i "s|\(\"curl\".*\)'',|\1'$(which curl)',|" /var/www/rutorrent/conf/config.php
	sed -i "s|\(\"gzip\".*\)'',|\1'$(which gzip)',|" /var/www/rutorrent/conf/config.php
	sed -i "s|\(\"id\".*\)'',|\1'$(which id)',|" /var/www/rutorrent/conf/config.php
	sed -i "s|\(\"stat\".*\)'',|\1'$(which stat)',|" /var/www/rutorrent/conf/config.php

	wget https://raw.githubusercontent.com/peondusud/dedi.serv/master/rutorrent/conf/plugins.ini -O /var/www/rutorrent/conf/plugins.ini

	sed -i 's|false|"buildtorrent"|' /var/www/rutorrent/plugins/create/conf.php

	sed -i "s|\(pathToCreatetorrent = '\)';|\1$(which buildtorrent)';|" /var/www/rutorrent/plugins/create/conf.php
	sed -i "s|\(pathToExternals\['rar'\] = '\)';|\1$(which rar)';|"  /var/www/rutorrent/plugins/filemanager/conf.php
	sed -i "s|\(pathToExternals\['zip'\] = '\)';|\1$(which zip)';|"  /var/www/rutorrent/plugins/filemanager/conf.php
	sed -i "s|\(pathToExternals\['unzip'\] = '\)';|\1$(which unzip)';|"  /var/www/rutorrent/plugins/filemanager/conf.php
	sed -i "s|\(pathToExternals\['tar'\] = '\)';|\1$(which tar)';|"  /var/www/rutorrent/plugins/filemanager/conf.php
	sed -i "s|\(pathToExternals\['gzip'\] = '\)';|\1$(which gzip)';|"  /var/www/rutorrent/plugins/filemanager/conf.php
	sed -i "s|\(pathToExternals\['bzip2'\] = '\)';|\1$(which bzip2)';|"  /var/www/rutorrent/plugins/filemanager/conf.php
}

nginx_install () {
	# http2 nginx version
	apt install -y nginx-extras/jessie-backports
	apt install -y openssl/jessie-backports
}

nginx_conf () {
	#add nginx to www-data group
	usermod -a -G www-data nginx
	wget https://github.com/peondusud/dedi.serv/archive/master.zip
	unzip master.zip
	cp -rv dedi.serv-master/nginx /etc/
	rm -rf dedi.serv-master master.zip
	mkdir -p /var/spool/nginx/client
	mkdir -p /etc/nginx/passwd
	mkdir -p /etc/nginx/sites-enabled
	htpasswd -s -c  /etc/nginx/passwd/rutorrent_passwd ${USERNAME}
	chmod 640 /etc/nginx/passwd/*
	chown --changes www-data:www-data /etc/nginx/passwd/*	
	systemctl restart nginx.service
}

nginx_ssl_conf () {	
	mkdir -p /etc/nginx/ssl
	if [ ! -f /etc/nginx/ssl/dhparam.pem ]; then
		openssl dhparam -out /etc/nginx/ssl/dhparam.pem 4096
	else
		openssl dhparam -inform PEM -in /etc/nginx/ssl/dhparam.pem -check
	fi
}

# Let's encrypt part
letencrypt_conf () {
	MYMAIL=webmaster@${MYDOMAIN}
	
	apt-get install git
	git clone https://github.com/letsencrypt/letsencrypt /opt/letsencrypt --depth=1
	mkdir -p /var/www/letsencrypt
	mkdir -p /etc/letsencrypt/configs
	mkdir -p /var/log/letsencrypt
	wget https://raw.githubusercontent.com/peondusud/dedi.serv/master/letsencrypt/letsencrypt.ini -O /etc/letsencrypt/configs/${MYDOMAIN}.conf
	sed -i "s|<domain>|${MYDOMAIN}|" /etc/letsencrypt/configs/${MYDOMAIN}.conf
	sed -i "s|<mail>|${MYMAIL}|" /etc/letsencrypt/configs/${MYDOMAIN}.conf
	sed -i "s|<domain>|${MYDOMAIN}|" /etc/nginx/sites-available/rutorrent.conf

	wget https://raw.githubusercontent.com/peondusud/dedi.serv/master/nginx/sites-available/letsencrypt.conf -O /etc/nginx/sites-available/letsencrypt.conf
	ln -s /etc/nginx/sites-available/letsencrypt.conf /etc/nginx/sites-enabled/letsencrypt.conf
	service nginx reload
	
	#renew cron.monthly task
	echo '#!/bin/sh\nln -s /etc/nginx/sites-available/letsencrypt.conf /etc/nginx/sites-enabled/letsencrypt.conf\n/opt/letsencrypt/letsencrypt-auto renew >> /var/log/letsencrypt/renew.log\nservice nginx reload' > /etc/cron.monthly/renew_certs

	# generate certs
	/opt/letsencrypt/letsencrypt-auto certonly --config /etc/letsencrypt/configs/${MYDOMAIN}.conf
	echo "Let's encrypt Certs will be save in /etc/letsencrypt/live/"

	# enable nginx ssl
	ln -s /etc/nginx/sites-available/rutorrent.conf /etc/nginx/sites-enabled/rutorrent.conf
	service nginx reload

}

php7_conf () {
	sed -i "s/^\(upload_max_filesize =\).*$/\1 10M/" /etc/php/7.0/fpm/php.ini
	sed -i "s/^;\(date\.timezone =\).*$/\1 Europe\/Paris/" /etc/php/7.0/fpm/php.ini
	systemctl restart php7.0-fpm.service
}



install_torrent () {
	add_repo	
	apt-get install  --no-install-suggests -y ${BUILD_DEPS} ${NGINX_DEPS} ${TORRENT_DEPS}
	type -P xmlrpc-c-config >/dev/null 2>&1
	if [ $? -eq 1 ]; then
		xmlrpc_build
	fi
	
	if ! [ -e /usr/local/lib/libtorrent.so ]; then	
		libtorrent_build
	fi
	
	type -P rtorrent >/dev/null 2>&1
	if [ $? -eq 1 ]; then
		rtorrent_build
	fi
	rtorrent_config	
	rutorrent_install
	rutorrent_conf
	php7_conf
	nginx_install
	nginx_conf
	nginx_ssl_conf
	letencrypt_conf
}

fail2ban () {
      # based on https://wiki.meurisse.org/wiki/Fail2Ban
      wget -O- http://neuro.debian.net/lists/jessie.de-m.libre > /etc/apt/sources.list.d/neurodebian.sources.list
      apt-key adv --recv-keys --keyserver hkp://pgp.mit.edu:80 0xA5D32F012649A5A9
      apt-get update
      
      echo "popularity-contest      popularity-contest/participate  boolean false"|  debconf-set-selections
      #echo "popularity-contest      popularity-contest/submiturls   string"|  debconf-set-selections
      apt-get install --no-install-recommends --no-install-suggests -y fail2ban python-pyinotify rsyslog whois

      wget https://github.com/peondusud/dedi.serv/blob/master/fail2ban/jail.local -O /etc/fail2ban/jail.local
      #mv fail2ban/jail.local /etc/fail2ban/jail.local

      wget https://github.com/peondusud/dedi.serv/blob/master/fail2ban/jail.d/recidive.conf -O /etc/fail2ban/jail.d/recidive.conf
      #mv fail2ban/jail.d/recidive.conf /etc/fail2ban/jail.d/recidive.conf

      sed -i "s|\(port *=\) ssh|\1 ${SSH_PORT}|" /etc/fail2ban/jail.local
      systemctl start fail2ban
      systemctl enable fail2ban
}

portsentry () {
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

hardening_srv () {
	fail2ban
	portsentry
	#rkhunter
	#disable ipv6 support
	sed -i 's|\(GRUB_CMDLINE_LINUX=\)""|\1"ipv6.disable=1"|' /etc/default/grub
	update-grub2	
}

mono_install () {
	sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
	echo "deb http://download.mono-project.com/repo/debian wheezy main" 					> /etc/apt/sources.list.d/mono-xamarin.list
	echo "deb http://download.mono-project.com/repo/debian wheezy-apache24-compat main"	 	>> /etc/apt/sources.list.d/mono-xamarin.list
	echo "deb http://download.mono-project.com/repo/debian wheezy-libjpeg62-compat main" 	>> /etc/apt/sources.list.d/mono-xamarin.list
	echo "deb http://download.mono-project.com/repo/debian 38-security main" 	>> /etc/apt/sources.list.d/mono-xamarin.list
	echo "deb http://download.mono-project.com/repo/debian 310-security main" 	>> /etc/apt/sources.list.d/mono-xamarin.list
	echo "deb http://download.mono-project.com/repo/debian 312-security main" 	>> /etc/apt/sources.list.d/mono-xamarin.list
	echo "deb http://download.mono-project.com/repo/debian 40-security main" 	>> /etc/apt/sources.list.d/mono-xamarin.list
	apt-get update
	apt-get install -y mono-complete  ca-certificates-mono
}

web_deps () {
	curl -sL https://deb.nodesource.com/setup_4.x | bash -
	apt-get install -y nodejs
	npm install -g bower
	npm install -g gulp
	curl -sS https://getcomposer.org/installer | php
	mv composer.phar /usr/local/bin/composer
}

plex_install () {
	echo "deb http://shell.ninthgate.se/packages/debian jessie main" > /etc/apt/sources.list.d/plexmediaserver.list
	curl http://shell.ninthgate.se/packages/shell.ninthgate.se.gpg.key | apt-key add -
	apt-get update
	apt-get install plexmediaserver
	service plexmediaserver start
}

emby_install () {
	echo 'deb http://download.opensuse.org/repositories/home:/emby/Debian_8.0/ /' > /etc/apt/sources.list.d/embyserver.list 
	curl http://download.opensuse.org/repositories/home:emby/Debian_8.0/Release.key | apt-key add -
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
	apt-get update
	apt-get install mono-complete emby-server
	service emby-server start
}

sickrage_install () {	
	git clone https://github.com/SickRage/SickRage.git /opt/sickrage
	echo "SR_USER=${rtorrent_user}"  > /etc/default/sickrage
	echo "SR_HOME=/opt/sickrage/"    >> /etc/default/sickrage
	echo "SR_DATA=/opt/sickrage/"    >> /etc/default/sickrage
	echo "SR_GROUP=${rtorrent_user}" >> /etc/default/sickrage
	chown -R ${rtorrent_user}:${rtorrent_user} /opt/sickrage
	sed -i 's|web_root = ""|web_root = \"/sickrage\"|' /opt/sickrage/config.ini
	sed -i 's|handle_reverse_proxy.*$|handle_reverse_proxy = 1|' /opt/sickrage/config.ini
	
	#service 
	addgroup --system sickrage
	adduser --disabled-password --system --home /opt/sickrage --gecos "SickRage" --ingroup sickrage sickrage
	chown -R sickrage:sickrage /opt/sickrage
	cp /opt/sickrage/runscripts/init.systemd /etc/systemd/system/sickrage.service 
	chown root:root /etc/systemd/system/sickrage.service
	chmod 644 /etc/systemd/system/sickrage.service
	# let systemd know there is a new service
	systemctl daemon-reload
	systemctl enable sickrage
	systemctl start sickrage
}

couchpotato_install () {
	useradd --system --user-group --no-create-home --disabled-password couchpotato
	usermod -a -G ${rtorrent_user} couchpotato
	apt-get install -y python-lxml python-pip python-setuptools libssl-dev libffi-dev python-dev
	#pip install -U pyopenssl
	git clone https://github.com/CouchPotato/CouchPotatoServer.git
	
	#service
	cp CouchPotatoServer/init/couchpotato.service /etc/systemd/system/couchpotato.service
	chown root:root /etc/systemd/system/couchpotato.service
	chmod 644 /etc/systemd/system/couchpotato.service
	# let systemd know there is a new service
	systemctl daemon-reload
	systemctl enable couchpotato
	systemctl start couchpotato
}

koel_install () {
	git clone https://github.com/phanan/koel.git /var/www/koel
	cd /var/www/koel
	npm install
	composer install
	gulp --production
	chown -R www-data:www-data /var/www/koel
	php artisan koel:init
echo "APP_ENV=production
APP_DEBUG=false
APP_URL=https://koel.ndd.tld
DB_CONNECTION=mysql
DB_HOST=localhost
DB_DATABASE=dbKoel
DB_USERNAME=userKoel
DB_PASSWORD=passSQL
ADMIN_EMAIL=mail@exemple.com
ADMIN_NAME=user
ADMIN_PASSWORD=psw" > /var/www/koel/.env
	service nginx restart	
}


tardis_install () {
	git clone https://github.com/Jedediah04/TARDIStart.git /var/www/tardistart
	cd /var/www/tardistart
	bower install --allow-root
	sed -i "s|domain.tld|${MYDOMAIN}|g" /var/www/tardistart/admin/service.json
	chown -R www-data:www-data /var/www/tardistart
}

headphones_install () {
	# https://github.com/rembo10/headphones/wiki/Installation
	adduser --system --no-create-home headphones
	git clone https://github.com/rembo10/headphones.git /opt/headphones
	chown -R headphones:nogroup /opt/headphones
	exec python Headphones.py & > /dev/null ; kill -9 $!
	echo "HP_USER=headphones         #$RUN_AS, username to run headphones under, the default is headphones" > /etc/default/headphones
	echo "HP_HOME=/opt/headphones    #$APP_PATH, the location of Headphones.py, the default is /opt/headphones" >> /etc/default/headphones
	echo "HP_DATA=/opt/headphones    #$DATA_DIR, the location of headphones.db, cache, logs, the default is /opt/headphones" >> /etc/default/headphones
	cp /opt/headphones/init-scripts/init.ubuntu /etc/init.d/headphones
	chmod +x /etc/init.d/headphones
	update-rc.d headphones defaults
	update-rc.d headphones enable
	echo "http_host = 127.0.0.1" 	> /opt/headphones/config.ini
	echo "customhost = ${MYDOMAIN}" > /opt/headphones/config.ini 
	echo "http_port = 8181 #beware sickrage" > /opt/headphones/config.ini
	service headphones start	 
}


sonarr_install () {
	# https://github.com/Sonarr/Sonarr/wiki/Installation
	mono_install
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys FDA5DFFC
	echo "deb http://apt.sonarr.tv/ master main" > /etc/apt/sources.list.d/sonarr.list
	apt-get update
	apt-get install -y nzbdrone apt-transport-https
	mono --debug /opt/NzbDrone/NzbDrone.exe	
}

jackett_install () {
	mono_install
	adduser --system --no-create-home jackett
	apt-get install -y libcurl-dev
	JACKETT_VER=$(curl -s   https://github.com/Jackett/Jackett/releases/latest |  grep -Pom 1 "v\d\.\d\.\d{3}")
	wget https://github.com/Jackett/Jackett/releases/download/${JACKETT_VER}/Jackett.Binaries.Mono.tar.gz -O /tmp/Jackett.Binaries.Mono.tar.gz
	tar -xzf /tmp/Jackett.Binaries.Mono.tar.gz -C /opt
	mv /opt/Jackett /opt/jackett
	chown -R jackett:jackett /opt/jackett
	mono /opt/jackett/JackettConsole.exe
	
	systemctl daemon-reload
	systemctl enable jackett
	systemctl start jackett
	#http://ip.address:9117
}
netdata_install () {
	apt-get  install -y  zlib1g-dev uuid-dev libmnl-dev gcc make git autoconf autoconf-archive autogen automake pkg-config curl  python-yaml python-mysqldb python-psycopg2 netcat
	git clone --depth=1 https://github.com/firehol/netdata.git /tmp/netdata
	cd /tmp/netdata;
	./netdata-installer.sh  --dont-wait --libs-are-really-here
	
	killall netdata
	/tmp/netdata/system/netdata.service /etc/systemd/system/
	# let systemd know there is a new service
	systemctl daemon-reload
	# enable netdata at boot
	systemctl enable netdata
	# start netdata
	service netdata start
	#http://127.0.0.1:19999/
}

syncthing_install () {
	# Add the release PGP keys:
	curl -s https://syncthing.net/release-key.txt | sudo apt-key add -
	# Add the "release" channel to your APT sources:
	echo "deb http://apt.syncthing.net/ syncthing release" > /etc/apt/sources.list.d/syncthing.list
	# Update and install syncthing:
	sudo apt-get update
	sudo apt-get install syncthing
}

settings_warning
install_basics
#docker_config
install_torrent
hardening_srv
