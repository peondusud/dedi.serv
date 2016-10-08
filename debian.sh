#!/bin/bash

USERNAME="peon"
SSH_PORT=22222
MYDOMAIN=peon.peon.org


SHELL_PATH=$(dirname $0)

BUILD_DEPS="git subversion automake libtool libcppunit-dev build-essential pkg-config libssl-dev libcurl4-openssl-dev libsigc++-2.0-dev libncurses5-dev"
NGINX_DEPS="zlib1g-dev libpcre3 libpcre3-dev unzip apache2-utils php7.0 php7.0-cli php7.0-fpm php7.0-curl php7.0-geoip php7.0-xml php7.0-mbstring php7.0-zip php7.0-json php7.0-gd php7.0-mcrypt php7.0-msgpack php7.0-memcached php7.0-intl php7.0-sqlite3"
TORRENT_DEPS="libncursesw5 screen curl unzip unrar rar zip bzip2 ffmpeg buildtorrent mediainfo"

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
      echo "ssh-copy-id -i ~/.ssh/id_rsa.pub root@domain.org"

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
      echo "deb http://ftp.debian.org/debian jessie-backports main" >> /etc/apt/sources.list
      apt-get update
      apt-get install -y nftables ulogd2 ulogd2-sqlite3 ulogd2-pcap ulogd2-json
      #nft flush table filter

      mkdir -p /etc/nftables
      wget https://raw.githubusercontent.com/peondusud/dedi.serv/master/nftables/fw.ruleset -O /etc/nftables/fw.ruleset
      #mv nftables/fw.ruleset /etc/nftables/fw.ruleset

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
}

fail2ban_config () {
      # based on https://wiki.meurisse.org/wiki/Fail2Ban
      wget -O- http://neuro.debian.net/lists/jessie.de-m.libre > /etc/apt/sources.list.d/neurodebian.sources.list
      apt-key adv --recv-keys --keyserver hkp://pgp.mit.edu:80 0xA5D32F012649A5A9
      apt-get update
      apt-get install --no-install-recommends --no-install-suggests -y fail2ban python-pyinotify rsyslog whois

      wget https://github.com/peondusud/dedi.serv/blob/master/fail2ban/jail.local -O /etc/fail2ban/jail.local
      #mv fail2ban/jail.local /etc/fail2ban/jail.local

      wget https://github.com/peondusud/dedi.serv/blob/master/fail2ban/jail.d/recidive.conf -O /etc/fail2ban/jail.d/recidive.conf
      #mv fail2ban/jail.d/recidive.conf /etc/fail2ban/jail.d/recidive.conf

      sed -i "s|\(port *=\) ssh|\1 ${SSH_PORT}|" /etc/fail2ban/jail.conf
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
      fail2ban_config
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
	wget https://raw.githubusercontent.com/peondusud/dedi.serv/master/rtorrent/.rtorrent.rc
	mkdir -p "/home/${rtorrent_user}/rtorrent"/{.session,download,complete,log,watch/load,watch/start}
	sed -i "s/<username>/${rtorrent_user}/g" /home/${rtorrent_user}/.rtorrent.rc
	chown -R ${rtorrent_user}:${rtorrent_user} /home/${rtorrent_user}/{*,.*}
}

rutorrent_install () {
	mkdir -p /var/www
	cd /var/www
	git clone https://github.com/Novik/ruTorrent.git rutorrent
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
	htpasswd -B -c  /etc/nginx/passwd/rutorrent_passwd ${USERNAME}
	chmod 640 /etc/nginx/passwd/*
	chown --changes www-data:www-data /etc/nginx/passwd/*	
	systemctl restart nginx.service
}

nginx_ssl_conf () {
	
	mkdir -p /etc/nginx/ssl
	if [ ! -f /etc/nginx/ssl/dhparam.pem ]; then
		openssl dhparam -out dhparam.pem 4096
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
	cp -f ${SHELL_PATH}/letsencrypt.ini /etc/letsencrypt/configs/${MYDOMAIN}.conf
	sed -i "s|<domain>|${MYDOMAIN}|" /etc/letsencrypt/configs/${MYDOMAIN}.conf
	sed -i "s|<mail>|${MYMAIL}|" /etc/letsencrypt/configs/${MYDOMAIN}.conf
	sed -i "s|<domain>|${MYDOMAIN}|" /etc/nginx/sites-available/rutorrent.conf

	ln -s /etc/nginx/sites-available/letsencrypt.conf /etc/nginx/conf.d/letsencrypt.conf;
	service nginx restart;
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
	nginx_conf
}

nginx_install () {
	echo "deb http://httpredir.debian.org/debian jessie-backports main contrib non-free" >> /etc/apt/sources.list
	apt-get update
	
	# http2 nginx version
	apt install -y nginx-extras/jessie-backports

	cd /tmp
	git clone https://github.com/peondusud/nginx.SSL.offloader.git
	cd nginx.SSL.offloader
	bash -x conf.sh
}

settings_warning
install_basics
#docker_config
#nginx_install
install_torrent
