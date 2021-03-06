#!/bin/bash

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
	ret=$(command -v npm| wc -l) || true
	if [ $ret -eq 0 ] ; then
		curl -sL https://deb.nodesource.com/setup_4.x | bash -
		apt-get install -y nodejs
	fi
	ret=$(command -v bower| wc -l) || true
	if [ $ret -eq 0 ] ; then	
		npm install -g bower
	fi
	ret=$(command -v gulp| wc -l) || true
	if [ $ret -eq 0 ] ; then	
		npm install -g gulp
	fi
	if ! [ -f "/usr/local/bin/composer" ] ; then
		curl -sS https://getcomposer.org/installer | php
		mv composer.phar /usr/local/bin/composer
	fi
	ret=$(command -v mono| wc -l) || true
	if [ $ret -eq 0 ] ; then
		mono_install
	fi
}

plex_install () {
	# https://support.plex.tv/hc/en-us/articles/201543147-What-network-ports-do-I-need-to-allow-through-my-firewall-
	PLEX_DEPS="alsa-base alsa-utils alsa-oss oss-compat libasound2-plugins"
	#echo "deb https://downloads.plex.tv/repo/deb/ public main" > /etc/apt/sources.list.d/plexmediaserver.list
	echo "deb http://shell.ninthgate.se/packages/debian jessie main" > /etc/apt/sources.list.d/plexmediaserver.list
	curl http://shell.ninthgate.se/packages/shell.ninthgate.se.gpg.key | apt-key add -
	# When enabling this repo please remember to add the PlexPublic.Key into the apt setup.
	# wget -q https://downloads.plex.tv/plex-keys/PlexSign.key -O - | sudo apt-key add -
	#deb https://downloads.plex.tv/repo/deb/ public main

	apt-get update
	apt-get install -y ${PLEX_DEPS} plexmediaserver
	service plexmediaserver start
}

plex_plugins () {
	plex_plugins_dir="/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Plug-ins"
	# Trakt.tv (for Plex)
	# https://github.com/trakt/Plex-Trakt-Scrobbler
	last_ver=$(curl -Ls https://github.com/trakt/Plex-Trakt-Scrobbler/releases/latest | sed  -n 's|^.*"\(/.*.zip\)".*$|\1|p' )
	wget https://github.com$last_ver -O /tmp/Plex-Trakt-Scrobbler.zip
	unzip /tmp/Plex-Trakt-Scrobbler.zip -d /tmp/
	find /tmp -type d -name "Trakttv.bundle" -exec mv {} "${plex_plugins_dir}/" \; || true
	rm -rf /tmp/Plex-Trakt-Scrobbler.zip
	
	# Sub-Zero for Plex
	# https://github.com/pannal/Sub-Zero.bundle
	last_ver=$(curl -Ls https://github.com/pannal/Sub-Zero.bundle/releases/latest | sed -n 's|^.*"\(/.*release.*.zip\)".*$|\1|p' )
	wget https://github.com$last_ver -O /tmp/Plex-Sub-Zero.zip
	unzip /tmp/Plex-Sub-Zero.zip -d /tmp/
	mv /tmp/Sub-Zero.bundle "${plex_plugins_dir}/"
	rm -rf /tmp/Plex-Sub-Zero.zip
	
	# Plex Request Channel
	# https://github.com/ngovil21/PlexRequestChannel.bundle
	wget https://github.com/ngovil21/PlexRequestChannel.bundle/archive/master.zip -O /tmp/Plex-RequestChannel.zip
	unzip /tmp/Plex-RequestChannel.zip -d /tmp/
	mv /tmp/PlexRequestChannel.bundle-master "${plex_plugins_dir}/PlexRequestChannel.bundle"
	rm -rf /tmp/Plex-RequestChannel.zip
	
	# ComicReader
	# https://github.com/coryo/ComicReader.bundle
	apt-get install unrar p7zip
	last_ver=$(curl -Ls https://github.com/coryo/ComicReader.bundle/releases/latest | sed -n 's|^.*"\(/.*.zip\)".*$|\1|p' )
	wget https://github.com$last_ver -O /tmp/Plex-ComicReader.zip
	unzip /tmp/Plex-ComicReader.zip -d /tmp/
	find /tmp/ -type d -name "ComicReader.bundle*" -exec mv {} "${plex_plugins_dir}/ComicReader.bundle" \; || true
	rm -rf /tmp/Plex-ComicReader.zip
	



}


wetty_install () {
	# Wetty = Web + tty
	# https://github.com/krishnasrinivas/wetty 
	git clone https://github.com/krishnasrinivas/wetty /opt/wetty
	cd /opt/wetty/
	npm install
	#node /opt/wetty/app.js -p 3000 --sshport 22222 --sshuser peon
	cp $DIR/systemd/system/wetty.service /etc/systemd/system/
	sed -i "s|@SSH_USER@|${USERNAME}|"  /etc/systemd/system/wetty.service
	sed -i "s|@SSH_PORT@|${SSH_PORT}|"  /etc/systemd/system/wetty.service
	systemctl daemon-reload
	#systemctl enable wetty
	#systemctl start wetty
}

emby_install () {
	echo 'deb http://download.opensuse.org/repositories/home:/emby/Debian_8.0/ /' > /etc/apt/sources.list.d/embyserver.list
	apt-key adv --keyserver keyserver.ubuntu.com --recv-key 0A506F712A7D8A28
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
	curl -L http://download.opensuse.org/repositories/home:/emby/Debian_8.0/Release.key | apt-key add -
		
	apt-get update
	apt-get install -y mono-complete emby-server
	service emby-server start
}

subtitles_install () {
	# https://github.com/agermanidis/autosub
	#pip install autosub
	
	# Auto-Sub Bootstrap Bill
	# https://github.com/BenjV/autosub-bootstrapbill
	pip install html5lib cheetah
	git clone https://github.com/BenjV/autosub-bootstrapbill /opt/autosub
	
}

mopidy_install () {
	wget -q -O - https://apt.mopidy.com/mopidy.gpg | sudo apt-key add -
	wget -q https://apt.mopidy.com/jessie.list -O /etc/apt/sources.list.d/mopidy.list
	apt-get update
	apt-get install -y mopidy
	service mopidy start
	
	# https://github.com/mopidy/mopidy-local-sqlite
	pip install Mopidy-Local-Sqlite
	
	# https://github.com/dirkgroenen/mopidy-mopify
	pip install Mopidy-Mopify
	
	# https://github.com/mopidy/mopidy-spotify
	apt-get install -y  libspotify12 python-spotify 
	pip install Mopidy-Spotify
	
	# https://github.com/jaedb/spotmop
	pip install Mopidy-Spotmop
	
	# https://github.com/mopidy/mopidy-youtube
	apt-get install -y gstreamer1.0-plugins-bad
	pip install Mopidy-YouTube
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
	
	# kill all running instances
	pkill -9 -f SickBeard.py || true
        nohup sudo -u sickrage python2 /opt/sickrage/SickBeard.py --nolaunch --datadir=${sickrage_datadir} > /dev/null &
	sleep 30; kill -2 $!; sleep 5; kill -9 $! || true
		
	# base path for reverseproxy (nginx)
	sed -i 's|web_root = ""|web_root = \"/sickrage\"|' ${sickrage_datadir}/config.ini
	sed -i 's|handle_reverse_proxy.*$|handle_reverse_proxy = 1|' ${sickrage_datadir}/config.ini
	
	#service
	cp $DIR/systemd/system/sickrage\@.service /etc/systemd/system/
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
	
	pkill -u couchpotato || true
	nohup sudo -u couchpotato /opt/couchpotato/CouchPotato.py --data_dir ${couchpotato_datadir} > /dev/null &
	sleep 30; kill -2 $!; sleep 5; kill -9 $! || true
	
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
	rm -rf /var/www/tardistart || true
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
	pkill -u headphones || true
	nohup sudo -u headphones python2 /opt/headphones/Headphones.py --nolaunch --datadir ${headphones_datadir} > /dev/null  &
	sleep 30; kill -2 $!; sleep 5; kill -9 $! || true

	#echo "customhost = ${MYDOMAIN}" 	>>    ${headphones_datadir}/config.ini 
	sed -i 's|\(http_root =\).*|\1 /headphones|' ${headphones_datadir}/config.ini
	sed -i 's|\(http_port =\).*$|\1 8182|'  ${headphones_datadir}/config.ini

	cp $DIR/systemd/system/headphones\@.service /etc/systemd/system/
	chown root:root /etc/systemd/system/headphones\@.service
	chmod 644 /etc/systemd/system/headphones\@.service
	systemctl daemon-reload
	systemctl enable headphones@${rtorrent_user}
	systemctl start headphones@${rtorrent_user} 
}


sonarr_install () {
	# https://github.com/Sonarr/Sonarr/wiki/Installation
	ret=$(command -v mono| wc -l) || true
	if [ $ret -eq 0 ] ; then
		mono_install
	fi
	
	sonarr_datadir=/home/${rtorrent_user}/.config/sonarr
	
	adduser --system --group --no-create-home --home /opt/NzbDrone --gecos "NzbDrone" sonarr
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys FDA5DFFC
	echo "deb http://apt.sonarr.tv/ master main" > /etc/apt/sources.list.d/sonarr.list
	apt-get update
	apt-get install -y nzbdrone apt-transport-https
	
	mkdir -p ${sonarr_datadir}
	chown -R sonarr:sonarr ${sonarr_datadir}
	chown -R sonarr:sonarr /opt/NzbDrone

	#create config file
	pkill -u sonarr || true
	nohup sudo -u sonarr mono /opt/NzbDrone/NzbDrone.exe -nobrowser -data=${sonarr_datadir} > /dev/null & 
	sleep 30; kill -2 $!; sleep 5; kill -9 $! || true
	
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
	ret=$(command -v mono| wc -l) || true
	if [ $ret -eq 0 ] ; then
		mono_install
	fi
	jackett_datadir=/home/${rtorrent_user}/.config/jackett
	adduser --system --group --no-create-home jackett
	#libcurl-dev virtual package ->  libcurl4-openssl-dev
	apt-get install -y libcurl4-openssl-dev
	JACKETT_VER=$(curl -s https://github.com/Jackett/Jackett/releases/latest |  grep -Pom 1 "v\d\.\d\.\d{3}")
	wget https://github.com/Jackett/Jackett/releases/download/${JACKETT_VER}/Jackett.Binaries.Mono.tar.gz -O /tmp/Jackett.Binaries.Mono.tar.gz
	tar -xzf /tmp/Jackett.Binaries.Mono.tar.gz -C /opt
	rm -rf /opt/jackett
	mv /opt/Jackett /opt/jackett
	chown -R jackett:jackett /opt/jackett
	
	mkdir -p ${jackett_datadir}
	chown -R jackett:jackett ${jackett_datadir}
	
	pkill -u jackett || true
	nohup sudo -u jackett mono /opt/jackett/JackettConsole.exe -d ${jackett_datadir} > /dev/null &
	sleep 30; kill -2 $!; sleep 5; kill -9 $! || true
	
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
	netdata_dir_tmp=/tmp/netdata
    apt-get update
	apt-get install -y zlib1g-dev uuid-dev libmnl-dev gcc make git autoconf autoconf-archive autogen automake pkg-config curl python-yaml python-mysqldb python-psycopg2 netcat
	git clone --depth=1 https://github.com/firehol/netdata.git ${netdata_dir_tmp} 
	cd ${netdata_dir_tmp} 
	
	./netdata-installer.sh --dont-wait --libs-are-really-here	
	killall netdata	|| true
	# remove external call (registry.my-netdata.io)
	sed -i "s|registry.my-netdata.io|${MYDOMAIN}/netdata|" /etc/netdata/netdata.conf

	rm -rf ${netdata_dir_tmp} || true
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
	#emby_install
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
