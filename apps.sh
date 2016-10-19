#!/bin/bash

PLEX_DEPS="alsa alsa-oss oss-compat libasound2-plugins"

mono_install () {
	sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
	echo "deb http://download.mono-project.com/repo/debian wheezy main" 					> /etc/apt/sources.list.d/mono.list
	echo "deb http://download.mono-project.com/repo/debian wheezy-apache24-compat main"	 	>> /etc/apt/sources.list.d/mono.list
	echo "deb http://download.mono-project.com/repo/debian wheezy-libjpeg62-compat main" 	>> /etc/apt/sources.list.d/mono.list
	echo "deb http://download.mono-project.com/repo/debian 38-security main" 	>> /etc/apt/sources.list.d/mono.list
	echo "deb http://download.mono-project.com/repo/debian 310-security main" 	>> /etc/apt/sources.list.d/mono.list
	echo "deb http://download.mono-project.com/repo/debian 312-security main" 	>> /etc/apt/sources.list.d/mono.list
	echo "deb http://download.mono-project.com/repo/debian 40-security main" 	>> /etc/apt/sources.list.d/mono.list
	apt-get update
	apt-get install -y mono-complete ca-certificates-mono
}

app_deps () {
	curl -sL https://deb.nodesource.com/setup_4.x | bash -
	apt-get install -y nodejs
	npm install -g bower
	npm install -g gulp
	if ! [ -f "/usr/local/bin/composer" ] ; then
		curl -sS https://getcomposer.org/installer | php
		mv composer.phar /usr/local/bin/composer
	fi
	mono_install
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
	addgroup --system sickrage
	adduser --disabled-password --system --home /opt/sickrage --gecos "SickRage" --ingroup sickrage sickrage
	
	git clone https://github.com/SickRage/SickRage.git /opt/sickrage
	
	chown -R sickrage:sickrage /opt/sickrage
	echo "SR_USER=sickrage"  > /etc/default/sickrage	
	echo "SR_GROUP=sickrage" >> /etc/default/sickrage
	echo "SR_HOME=/opt/sickrage/"    >> /etc/default/sickrage
	echo "SR_DATA=/opt/sickrage/"    >> /etc/default/sickrage
	
	#base path for reverseproxy (nginx)
	sed -i 's|web_root = ""|web_root = \"/sickrage\"|' /opt/sickrage/config.ini
	sed -i 's|handle_reverse_proxy.*$|handle_reverse_proxy = 1|' /opt/sickrage/config.ini
	
	#service 	
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
	git clone https://github.com/CouchPotato/CouchPotatoServer.git /opt/couchpotato
	
	#service
	cp /opt/couchpotato/init/couchpotato.service /etc/systemd/system/couchpotato.service
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
	sudo -u jackett mono --debug /opt/jackett/JackettConsole.exe -d /opt/jackett &
	kill -9 $!
	pkill -u jackett
	#base path for reverseproxy (nginx)
	sed -i 's|BasePathOverride": .*|BasePathOverride": "/jackett"|' /opt/jackett/ServerConfig.json
	#todo download systemd service
	cp $DIR/systemd/system/jackett.service /etc/systemd/system/jackett.service
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
	# remove external call (registry.my-netdata.io)
	sed -i "s|registry.my-netdata.io|${MYDOMAIN}/netdata|" /etc/netdata/netdata.conf
	/tmp/netdata/system/netdata.service /etc/systemd/system/netdata.service
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

apps () {
	plex_install
	emby_install
	sickrage_install
	couchpotato_install
	headphones_install
	tardis_install
	sonarr_install
	jackett_install
	netdata_install
	syncthing_install
}

app_deps
apps
