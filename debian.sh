#!/bin/bash

USERNAME="peon"
SSH_PORT=22222
MYDOMAIN=peon.org
DIR=/tmp/dedi.serv

SHELL_PATH=$(dirname $0)

set -xeuf -o pipefail


BUILD_DEPS="git subversion automake libtool libcppunit-dev build-essential pkg-config libssl-dev libcurl4-openssl-dev libsigc++-2.0-dev libncurses5-dev"
NGINX_DEPS="zlib1g-dev libpcre3 libpcre3-dev unzip apache2-utils php7.0 php7.0-cli php7.0-fpm php7.0-curl php7.0-geoip php7.0-xml php7.0-mbstring php7.0-zip php7.0-json php7.0-gd php7.0-mcrypt php7.0-msgpack php7.0-memcached php7.0-intl php7.0-sqlite3"
TORRENT_DEPS="libncursesw5 screen curl unzip unrar rar zip bzip2 ffmpeg buildtorrent mediainfo"


settings_warning () {
	read -p "USERNAME = " -i ${USERNAME} -e usr
	USERNAME=${usr:-USERNAME}
	read -p "USERNAME = " -i ${SSH_PORT} -e tmp
	SSH_PORT=${tmp:-SSH_PORT}	
	read -p "USERNAME = " -i ${MYDOMAIN} -e ret
	MYDOMAIN=${ret:-MYDOMAIN}	
	echo "USERNAME =  ${USERNAME}"
	echo "SSH_PORT = ${SSH_PORT}"		
	echo "MYDOMAIN = ${MYDOMAIN}"
	read -p "Is this a good (y/n)? " answer
	if echo "$answer" | grep -iq "^n" ;then
    		exit
	fi
}

install_req () {
      apt-get update || true
      apt-get -y dist-upgrade  || true
      apt-get install -y htop curl unzip git subversion nano vim zsh  || true
      apt-get remove -y bind9  || true
      #apt-get --purge autoremove 
}

new_user_config () {
      apt-get install -y sudo || true
      ret=$(id -u ${USERNAME} > /dev/null 2>&1; echo $?) || true
      if [ $ret -eq 1 ] ; then
            echo "Add new user: ${USERNAME}"
            useradd -ms /bin/zsh "${USERNAME}"
            passwd "${USERNAME}"
      fi
	  ret=$(grep "^${USERNAME}" /etc/sudoers /etc/ssh/sshd_config| wc -l) || true
	  if [ $ret -eq 0 ] ; then
      	echo "Add ${USERNAME} to sudoers"
      	echo "${USERNAME}    ALL=(ALL:ALL) ALL" >> /etc/sudoers
	  fi
}

ssh_config () {
      echo "setting SSH config"
      #ssh server conf
      sed -i "s|\(Port\).*$|\1 ${SSH_PORT}|" /etc/ssh/sshd_config
      sed -i "s|\(PermitRootLogin\).*$|\1 no|" /etc/ssh/sshd_config
      sed -i "s|\(X11Forwarding\).*$|\1 no|" /etc/ssh/sshd_config
      
      ret=$(grep "^AllowUsers.*${USERNAME}" /etc/ssh/sshd_config| wc -l) || true
      if [ $ret -eq 0 ] ; then
      	echo "AllowUsers ${USERNAME}" >> /etc/ssh/sshd_config
      fi
      ret=$(grep '^AddressFamily inet' /etc/ssh/sshd_config| wc -l) || true
      if [ $ret -eq 0 ] ; then
      	echo "AddressFamily inet # IPv4 only" >> /etc/ssh/sshd_config
	  fi
      echo "On your desktop, to use certificat:"
      echo "ssh-copy-id -i ~/.ssh/id_rsa.pub ${USERNAME}@MYDOMAIN"

      echo "Once done press [ENTER] to restart ssh service"
      read -n 1 -s
      systemctl restart ssh.service
}

sysctl_config () {
      cp $DIR/sysctl.d/local.conf  /etc/sysctl.d/local.conf
      # reload sysctl
      echo "reload sysctl config"
      sysctl --system
}

nftables_config () {
	ret=$(find /etc/apt/ -name *.list | xargs cat | grep  ^[[:space:]]*deb | grep -v deb-src | grep "jessie-backports main" | wc -l) || true
	if [ $ret -eq 0 ] ; then
		#echo "deb http://ftp.debian.org/debian jessie-backports main" >> /etc/apt/sources.list
		echo "deb http://httpredir.debian.org/debian jessie-backports main" >> /etc/apt/sources.list
	fi
	apt-get update
	apt-get install -y linux-image-amd64 nftables ulogd2 ulogd2-sqlite3 ulogd2-pcap ulogd2-json 
	#nft flush ruleset > linux-image-amd64

	mkdir -p /etc/nftables
	cp $DIR/nftables/fw.rules /etc/nftables/fw.rules
	sed -i "s|\${SSH_PORT}|${SSH_PORT}|" /etc/nftables/fw.rules

	# load ruleset from file
	#nft -f /etc/nftables/fw.rules
	# display full rules
	#nft list ruleset

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
	
	cp $DIR/systemd/system/nftables.service /etc/systemd/system/nftables.service
	# let systemd know there is a new service
	systemctl daemon-reload
	# enable netdata at boot
	systemctl enable nftables
	# start netdata
	service nftables start
}

cron_apt_config () {
	apt-get install -y cron-apt
	echo 'APTCOMMAND=/usr/bin/apt-get' 	> /etc/cron-apt/config
	echo 'MAILTO="root"' 			>> /etc/cron-apt/config
	echo 'OPTIONS="-o quiet=1 -o Dir::Etc::SourceList=/etc/apt/sources.list.d/security.list"' >> /etc/cron-apt/config

	echo 'deb http://httpredir.debian.org/debian jessie-updates main contrib non-free' > /etc/apt/sources.list.d/security.list
	
	echo 'dist-upgrade -y -o APT::Get::Show-Upgraded=true' > /etc/cron-apt/action.d/5-install	
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
	curl -L https://github.com/docker/compose/releases/download/1.8.1/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
	chmod +x /usr/local/bin/docker-compose
}


install_basics () {
	install_req
	new_user_config
	ssh_config
	sysctl_config
	nftables_config
	cron_apt_config
}

add_repo () {
	sed -ri 's/main$/main contrib non-free/g' /etc/apt/sources.list
	echo -e "\n#Depot Nginx\ndeb http://nginx.org/packages/debian/ jessie nginx" > /etc/apt/sources.list.d/nginx.list
	echo -e "\n#Depot Dotdeb\ndeb http://packages.dotdeb.org jessie all" > /etc/apt/sources.list.d/dotdeb.list
	echo -e "\n#Depot Multimedia\ndeb http://www.deb-multimedia.org jessie main non-free" > /etc/apt/sources.list.d/multimedia.list
	ret=$(find /etc/apt/ -name *.list | xargs cat | grep  ^[[:space:]]*deb | grep -v deb-src | grep "jessie-backports main" | wc -l) || true
	if [ $ret -eq 0 ] ; then
		#echo "deb http://ftp.debian.org/debian jessie-backports main" >> /etc/apt/sources.list
		echo "deb http://httpredir.debian.org/debian jessie-backports main" >> /etc/apt/sources.list
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
	git checkout $(git tag |tail -1)
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
	git checkout $(git tag |tail -1)
	./autogen.sh
	./configure --with-xmlrpc-c --with-ncurses
	make
	make install
	ldconfig
}

rtorrent_config () {
	rtorrent_user="${USERNAME}"
	
	mkdir -p "/home/${rtorrent_user}/rtorrent"/{.session,download,complete,log,watch/load,watch/start}
	cp $DIR/rtorrent/.rtorrent.rc /home/${rtorrent_user}/.rtorrent.rc
	sed -i "s/<username>/${rtorrent_user}/g" /home/${rtorrent_user}/.rtorrent.rc
	chown -R ${rtorrent_user}:${rtorrent_user} /home/${rtorrent_user}
	
	cp $DIR/systemd/system/rtorrent\@.service /etc/systemd/system/rtorrent\@.service
	systemctl daemon-reload
	systemctl start rtorrent@${rtorrent_user}
	systemctl enable rtorrent@${rtorrent_user}
}

rutorrent_install () {
	mkdir -p /var/www
	rm -rf /var/www/rutorrent
	git clone https://github.com/Novik/ruTorrent.git /var/www/rutorrent
	cp /var/www/rutorrent/images/favicon.ico /var/www/rutorrent/
	git clone https://github.com/xombiemp/rutorrentMobile.git /var/www/rutorrent/plugins/mobile
	git clone https://github.com/nelu/rutorrent-thirdparty-plugins /var/www/rutorrent/rutorrent-thirdparty-plugins
	#mv /var/www/rutorrent/rutorrent-thirdparty-plugins/ /var/www/rutorrent/plugins/
	find /var/www/rutorrent/rutorrent-thirdparty-plugins/  -maxdepth 1 -type d -not -iwholename '*.git' | tail -n +2 | xargs -I {} mv {} /var/www/rutorrent/plugins/
	rm -rf /var/www/rutorrent/rutorrent-thirdparty-plugins
	chown -R www-data:www-data /var/www/rutorrent
}


rutorrent_conf () {
	sed -i "s|\(\"php\".*\)'',|\1'$(which php)',|" /var/www/rutorrent/conf/config.php
	sed -i "s|\(\"curl\".*\)'',|\1'$(which curl)',|" /var/www/rutorrent/conf/config.php
	sed -i "s|\(\"gzip\".*\)'',|\1'$(which gzip)',|" /var/www/rutorrent/conf/config.php
	sed -i "s|\(\"id\".*\)'',|\1'$(which id)',|" /var/www/rutorrent/conf/config.php
	sed -i "s|\(\"stat\".*\)'',|\1'$(which stat)',|" /var/www/rutorrent/conf/config.php

	cp $DIR/rutorrent/conf/plugins.ini /var/www/rutorrent/conf/plugins.ini

	sed -i 's|false|"buildtorrent"|' /var/www/rutorrent/plugins/create/conf.php

	sed -i "s|\(pathToCreatetorrent = '\)';|\1$(which buildtorrent)';|" /var/www/rutorrent/plugins/create/conf.php
	sed -i "s|\(pathToExternals\['rar'\] = '\)';|\1$(which rar)';|"  /var/www/rutorrent/plugins/filemanager/conf.php
	sed -i "s|\(pathToExternals\['zip'\] = '\)';|\1$(which zip)';|"  /var/www/rutorrent/plugins/filemanager/conf.php
	sed -i "s|\(pathToExternals\['unzip'\] = '\)';|\1$(which unzip)';|"  /var/www/rutorrent/plugins/filemanager/conf.php
	sed -i "s|\(pathToExternals\['tar'\] = '\)';|\1$(which tar)';|"  /var/www/rutorrent/plugins/filemanager/conf.php
	sed -i "s|\(pathToExternals\['gzip'\] = '\)';|\1$(which gzip)';|"  /var/www/rutorrent/plugins/filemanager/conf.php
	sed -i "s|\(pathToExternals\['bzip2'\] = '\)';|\1$(which bzip2)';|"  /var/www/rutorrent/plugins/filemanager/conf.php
	chown -R www-data:www-data /var/www/rutorrent
}

nginx_install () {
	# http2 nginx version
	rm /etc/nginx/sites-enabled/default || true
	apt-get install -y nginx-extras || true
	rm /etc/nginx/sites-enabled/default || true
	apt-get -f install -y || true	
	apt-get install -y openssl -t jessie-backports || true
}

nginx_conf () {
	ret=$(getent passwd nginx |wc -l) || true
	if ! [ $ret -eq 0 ]; then
		#add nginx to www-data group
		usermod -a -G www-data nginx
	fi
	cp -rv $DIR/nginx /etc/	
	mkdir -p /etc/nginx/passwd
	mkdir -p /etc/nginx/sites-enabled
	mkdir -p /var/spool/nginx/client
	htpasswd -s -c /etc/nginx/passwd/rutorrent_passwd ${USERNAME}
	chmod 640 /etc/nginx/passwd/*
	chown -R --changes www-data:www-data /etc/nginx/passwd/	
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
	
	apt-get install git || true
	git clone https://github.com/letsencrypt/letsencrypt /opt/letsencrypt --depth=1	|| true
	mkdir -p /etc/letsencrypt/configs
	mkdir -p /var/www/letsencrypt
	mkdir -p /var/log/letsencrypt
	cp $DIR/letsencrypt/letsencrypt.ini /etc/letsencrypt/configs/${MYDOMAIN}.conf
	sed -i "s|<domain>|${MYDOMAIN}|" 	/etc/letsencrypt/configs/${MYDOMAIN}.conf
	sed -i "s|<mail>|${MYMAIL}|" 		/etc/letsencrypt/configs/${MYDOMAIN}.conf

	#renew cron.monthly task
	cp $DIR/cron.monthly/renew_certs /etc/cron.monthly/renew_certs
	
	cp $DIR/nginx/sites-available/letsencrypt.conf  /etc/nginx/sites-available/letsencrypt.conf	
	
	unlink /etc/nginx/sites-enabled/*
	ln -s /etc/nginx/sites-available/letsencrypt.conf /etc/nginx/sites-enabled/letsencrypt.conf
	service nginx reload
	# generate certs
	/opt/letsencrypt/letsencrypt-auto certonly --config /etc/letsencrypt/configs/${MYDOMAIN}.conf
	echo "Let's encrypt Certs will be save in /etc/letsencrypt/live/"
	unlink /etc/nginx/sites-enabled/letsencrypt.conf
	# enable nginx ssl
	ln -s /etc/nginx/sites-available/web.conf /etc/nginx/sites-enabled/web.conf
	service nginx restart
}

php7_conf () {
	sed -i "s/^\(upload_max_filesize =\).*$/\1 10M/" /etc/php/7.0/fpm/php.ini
	sed -i "s/^;\(date\.timezone =\).*$/\1 Europe\/Paris/" /etc/php/7.0/fpm/php.ini
	systemctl restart php7.0-fpm.service
}

install_torrent () {
	add_repo	
	apt-get install  --no-install-suggests -y ${BUILD_DEPS} ${NGINX_DEPS} ${TORRENT_DEPS} || true
	ret=$(type -P xmlrpc-c-config | wc -l) || true
	if [ $ret -eq 0 ]; then
		xmlrpc_build
	fi	
	if ! [ -e /usr/local/lib/libtorrent.so ]; then	
		libtorrent_build
	fi
	ret=$(type -P rtorrent | wc -l) || true
	if [ $ret -eq 0 ]; then
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


settings_warning
install_basics
source $DIR/hardening.sh
#docker_config
install_torrent
source $DIR/apps.sh

