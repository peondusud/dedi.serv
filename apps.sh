#!/bin/bash

PLEX_DEPS="alsa alsa-oss oss-compat libasound2-plugins"

mono_install () {
	echo "deb http://download.mono-project.com/repo/debian wheezy main" 					> /etc/apt/sources.list.d/mono.list
	echo "deb http://download.mono-project.com/repo/debian wheezy-apache24-compat main"	 	>> /etc/apt/sources.list.d/mono.list
	echo "deb http://download.mono-project.com/repo/debian wheezy-libjpeg62-compat main" 	>> /etc/apt/sources.list.d/mono.list
	echo "deb http://download.mono-project.com/repo/debian 38-security main" 	>> /etc/apt/sources.list.d/mono.list
	echo "deb http://download.mono-project.com/repo/debian 310-security main" 	>> /etc/apt/sources.list.d/mono.list
	echo "deb http://download.mono-project.com/repo/debian 312-security main" 	>> /etc/apt/sources.list.d/mono.list
	echo "deb http://download.mono-project.com/repo/debian 40-security main" 	>> /etc/apt/sources.list.d/mono.list
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
	apt-key adv --keyserver keyserver.ubuntu.com --recv-key A6A19B38D3D831EF
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
	apt-get install -y plexmediaserver
	service plexmediaserver start
}

emby_install () {
	echo 'deb http://download.opensuse.org/repositories/home:/emby/Debian_8.0/ /' > /etc/apt/sources.list.d/embyserver.list
	apt-key adv --keyserver keyserver.ubuntu.com --recv-key 0A506F712A7D8A28
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
	curl http://download.opensuse.org/repositories/home:emby/Debian_8.0/Release.key | apt-key add -
		
	apt-get update
	apt-get install -y mono-complete emby-server
	service emby-server start
}

sickrage_install () {
	sickrage_datadir=/home/${rtorrent_user}/.config/sickrage
	addgroup --system sickrage
	adduser --disabled-password --system --home /opt/sickrage --gecos "SickRage" --ingroup sickrage sickrage
	
	rm -rf  /opt/sickrage
        git clone https://github.com/SickRage/SickRage.git /opt/sickrage

	mkdir -p ${sickrage_datadir}
	chown -R sickrage:sickrage ${sickrage_datadir}
	chown -R sickrage:sickrage /opt/sickrage
	
	#kill all running instances
	pkill -9 -f SickBeard.py || true
        sudo -u sickrage python2 /opt/sickrage/SickBeard.py --nolaunch --datadir=${sickrage_datadir} &
	sleep 30; kill -9 $! || true
		
	#base path for reverseproxy (nginx)
	sed -i 's|web_root = ""|web_root = \"/sickrage\"|' ${sickrage_datadir}/config.ini
	sed -i 's|handle_reverse_proxy.*$|handle_reverse_proxy = 1|' ${sickrage_datadir}/config.ini
	
	#service
	cp $DIR/systemd/system/sickrage\@.service /etc/systemd/system/
	cp /opt/sickrage/runscripts/init.systemd /etc/systemd/system/sickrage\@.service
	chown root:root /etc/systemd/system/sickrage\@.service
	chmod 644 /etc/systemd/system/sickrage\@.service
	# let systemd know there is a new service
	systemctl daemon-reload
	systemctl enable sickrage@${rtorrent_user}
	systemctl start sickrage@${rtorrent_user}
}

couchpotato_install () {
	couchpotato_datadir=/home/${rtorrent_user}/.config/couchpotato
	useradd --system --user-group --no-create-home couchpotato || true
	#usermod -a -G ${rtorrent_user} couchpotato
	apt-get install -y python-lxml python-pip python-setuptools libssl-dev libffi-dev python-dev
	#pip install -U pyopenssl
	rm -rf /opt/couchpotato
	git clone https://github.com/CouchPotato/CouchPotatoServer.git /opt/couchpotato
	chown -R couchpotato:couchpotato /opt/couchpotato
	
	mkdir -p ${couchpotato_datadir}
	chown -R couchpotato:couchpotato ${couchpotato_datadir}
	
	pkill -u couchpotato
	sudo -u couchpotato /opt/couchpotato/CouchPotato.py --data_dir ${couchpotato_datadir} &
	sleep 30; kill -9 $! || true
	
	sed -i "s|\(url_base = \).*$|\1/couchpotato|"  ${couchpotato_datadir}/settings.conf
	
	#service
	cp $DIR/systemd/system/couchpotato\@.service /etc/systemd/system/
	chown root:root /etc/systemd/system/couchpotato\@.service
	chmod 644 /etc/systemd/system/couchpotato\@.service
	# let systemd know there is a new service
	systemctl daemon-reload
	systemctl enable couchpotato@${rtorrent_user}
	systemctl start couchpotato@${rtorrent_user}
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
	cp $DIR/tardistart/service.json /var/www/tardistart/admin/service.json
	sed -i "s|domain.tld|${MYDOMAIN}|g" /var/www/tardistart/admin/service.json	
	chown -R www-data:www-data /var/www/tardistart
}

headphones_install () {
	# https://github.com/rembo10/headphones/wiki/Installation
	headphones_datadir=/home/${rtorrent_user}/.config/headphones
	adduser --system --no-create-home --group headphones
	
	rm -rf /opt/headphones
	git clone https://github.com/rembo10/headphones.git /opt/headphones
	chown -R headphones:headphones /opt/headphones
	
	mkdir -p ${headphones_datadir}
	chown -R headphones:headphones ${headphones_datadir}	
	
	#create config file
	pkill -u headphones
	sudo -u headphones python2 /opt/headphones/Headphones.py --nolaunch --datadir ${headphones_datadir} &
	sleep 30; kill -9 $! || true

	#echo "customhost = ${MYDOMAIN}" 	>>    ${headphones_datadir}/config.ini 
	#echo "http_port = 8181 #beware sickrage" >>  ${headphones_datadir}/config.ini
	sed -i 's|\(http_root =\) /|\1 /headphones|'  ${headphones_datadir}/config.ini
	sed -i 's|\(http_port =\).*$|\1 8182|'  ${headphones_datadir}/config.ini

	cp $DIR/systemd/system/headphones\@.service /etc/systemd/system/
	chown root:root /etc/systemd/system/headphones\@.service
	chmod 644 /etc/systemd/system/headphones\@.service
	systemctl daemon-reload
	systemctl enable headphones@${rtorrent_user}
	systemctl start headphones@${rtorrent_user} 
}


sonarr_install () {
	sonarr_datadir=/home/${rtorrent_user}/.config/sonarr
	# https://github.com/Sonarr/Sonarr/wiki/Installation
	adduser --system --group --no-create-home --home /opt/NzbDrone --gecos "NzbDrone" sonarr
	mono_install
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys FDA5DFFC
	echo "deb http://apt.sonarr.tv/ master main" > /etc/apt/sources.list.d/sonarr.list
	apt-get update
	apt-get install -y nzbdrone apt-transport-https
	
	mkdir -p ${sonarr_datadir}
	chown -R sonarr:sonarr ${sonarr_datadir}
	chown -R sonarr:sonarr /opt/NzbDrone

	#create config file
	pkill -u sonarr
	sudo -u sonarr mono /opt/NzbDrone/NzbDrone.exe -nobrowser -data=${sonarr_datadir} & 
	sleep 60; kill -9 $! || true
	
	#base path for reverseproxy (nginx)
	sed -i 's|<UrlBase></UrlBase>|<UrlBase>/sonarr</UrlBase>|' ${sonarr_datadir}/config.xml
	
	#service
	cp $DIR/systemd/system/sonarr\@.service /etc/systemd/system/
	chown root:root /etc/systemd/system/sonarr\@.service
	chmod 644 /etc/systemd/system/sonarr\@.service
	systemctl daemon-reload
	systemctl enable sonarr@${rtorrent_user}
	systemctl start sonarr@${rtorrent_user}
}

jackett_install () {
	jackett_datadir=/home/${rtorrent_user}/.config/jackett
	mono_install
	adduser --system --group --no-create-home jackett
	#libcurl-dev virtual package ->  libcurl4-openssl-dev
	apt-get install -y libcurl4-openssl-dev
	JACKETT_VER=$(curl -s https://github.com/Jackett/Jackett/releases/latest |  grep -Pom 1 "v\d\.\d\.\d{3}")
	wget https://github.com/Jackett/Jackett/releases/download/${JACKETT_VER}/Jackett.Binaries.Mono.tar.gz -O /tmp/Jackett.Binaries.Mono.tar.gz
	tar -xzf /tmp/Jackett.Binaries.Mono.tar.gz -C /opt
	mv /opt/Jackett /opt/jackett
	chown -R jackett:jackett /opt/jackett
	
	mkdir -p ${jackett_datadir}
	chown -R jackett:jackett ${jackett_datadir}
	
	pkill -u jackett
	sudo -u jackett mono /opt/jackett/JackettConsole.exe -d ${jackett_datadir} &
	sleep 30; kill -9 $! || true
	
	#base path for reverseproxy (nginx)
	sed -i 's|BasePathOverride": .*|BasePathOverride": "/jackett"|' ${jackett_datadir}/ServerConfig.json
	
	#service
	cp $DIR/systemd/system/jackett\@.service /etc/systemd/system/
	chown root:root /etc/systemd/system/jackett\@.service
	chmod 644 /etc/systemd/system/jackett\@.service
	# let systemd know there is a new service
	systemctl daemon-reload
	systemctl enable jackett@${rtorrent_user}
	systemctl start jackett@${rtorrent_user}
	#http://ip.address:9117
}
netdata_install () {
	apt-get  install -y zlib1g-dev uuid-dev libmnl-dev gcc make git autoconf autoconf-archive autogen automake pkg-config curl  python-yaml python-mysqldb python-psycopg2 netcat
	git clone --depth=1 https://github.com/firehol/netdata.git /tmp/netdata
	cd /tmp/netdata
	
	./netdata-installer.sh --dont-wait --libs-are-really-here	
	killall netdata	
	# remove external call (registry.my-netdata.io)
	sed -i "s|registry.my-netdata.io|${MYDOMAIN}/netdata|" /etc/netdata/netdata.conf
	
	cp /tmp/netdata/system/netdata.service /etc/systemd/system/netdata.service
	systemctl daemon-reload
	systemctl enable netdata
	systemctl start netdata 
}

syncthing_install () {
	# Add the release PGP keys:
	curl -s https://syncthing.net/release-key.txt | sudo apt-key add -
	# Add the "release" channel to your APT sources:
	echo "deb http://apt.syncthing.net/ syncthing release" > /etc/apt/sources.list.d/syncthing.list
	# Update and install syncthing:
	sudo apt-get update
	sudo apt-get install -y syncthing
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
