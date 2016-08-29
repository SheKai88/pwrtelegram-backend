#!/bin/bash -e
# PWRTelegram installer script

# Created by Daniil Gentili (https://daniil.it)
# Copyright 2016 Daniil Gentili

#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.

#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

if [ $(id -u) -ne 0 ]; then
	sudo $0 $*
	exit $?
fi


echo "PWRTelegram installer script  Copyright (C) 2016  Daniil Gentili
This program comes with ABSOLUTELY NO WARRANTY; for details see https://github.com/pwrtelegram/pwrtelegram-backend/blob/master/LICENSE
This is free software, and you are welcome to redistribute it under certain conditions: see https://github.com/pwrtelegram/pwrtelegram-backend/blob/master/LICENSE

This program is created to run on ubuntu.
"
pwrexec() { su pwrtelegram -c "$*"; };
configure() {
	echo "Please enter your mysql database username and password."
	read -p "Username: " username
	read -p "Password: " password

	echo "Installing database..."
	mysql -u$username -p$password -e 'DROP DATABASE IF EXISTS `pwrtelegram`; CREATE DATABASE `pwrtelegram`;'
	mysql -u$username -p$password pwrtelegram < db.sql
	cp dummy_db_connect.php db_connect.php
	sed -i 's/user/'$username'/g;s/pass/'$password'/g' db_connect.php

	cd $homedir/pwrtelegram
	read -p "Type the domain name you intend to use for the main pwrtelegram API server (defaults to api.pwrtelegram.xyz): " api
	[ "$api" == "" ] && api="api.pwrtelegram.xyz"
	read -p "Type the domain name you intend to use for the beta pwrtelegram API server (defaults to beta.pwrtelegram.xyz): " beta
	[ "$beta" == "" ] && beta="beta.pwrtelegram.xyz"
	read -p "Type the domain name you intend to use for the pwrtelegram storage server (defaults to storage.pwrtelegram.xyz): " storage
	[ "$storage" == "" ] && storage="storage.pwrtelegram.xyz"

	echo "Configuring pwrtelegram..."
	sed -i 's/api\.pwrtelegram\.xyz/'$api'/g;s/beta\.pwrtelegram\.xyz/'$beta'/g;s/storage\.pwrtelegram\.xyz/'$storage'/g' Caddyfile storage_url.php

	cd $homedir
	echo "Configuring tg-cli (please enter your phone number now...)"
	pwrexec "$homedir/pwrtelegram/tg/bin/telegram-cli -e quit"
	tg=$(pwrexec $homedir/pwrtelegram/tg/bin/telegram-cli -e 'get_self' --json -R)
	tg=$(echo "$tg" | sed '/\"peer_id\": /!d;s/.*\"peer_id\": //g;s/,.*//g')

	sed 's/140639228/'$tg'/g' -i $homedir/pwrtelegram/storage_url.php

	echo "That's it, pretty much!
You have configured PWRTelegram in the following way:
Main API server (syncs with pwrtelegram github repo automatically every minute to stay updated): $api
Beta API server (local clone of the PWRTelegram repository that you can use to test new features and debug the API without touching the main API): $beta
Storage server (script that serves files downloaded by the PWRTelegram API): $storage

Now you have to complete the installation by doing the following things:

1.

Edit $homedir/pwrtelegram/Caddyfile to disable or change the source repo of the PWRTelegram main API.

2.

Once you have finished making your changes start the API with
$homedir/pwrtelegram/start_stop.sh start

3.

Star, watch and submit pull requests to the repositories of this project (https://github.com/pwrtelegram), subscribe to the official PWRTelegram channel (https://telegram.me/pwrtelegram), join the official PWRTelegram chat (https://telegram.me/pwrtelegramgroup), follow the official PWRTelegram account on Twitter (https://twitter.com/PWRTelegram).
Follow the creator (Daniil Gentili, https://daniil.it) on github (https://github.com/danog), contact him on Telegram (https://telegram.me/danogentili) or on Twitter (https://twitter.com/DaniilGentili)

And (optional but recommended) support the developer with a donation @ https://paypal.me/danog :)

Here are the paths of the log files:
* Caddy: $homedir/pwrtelegram/caddy.log
* API endpoints (server log): $homedir/pwrtelegram/api.log
* Storage server (server log): $homedir/pwrtelegram/storage.log
* API and storage (php log): /tmp/php-error-index.log


Dropping you to a shell as user pwrtelegram...
"
	su pwrtelegram
	echo 'Bye!'
}

tmpdir=/tmp/pwrtelegram_tmp

if [ "$1" == "docker" -a "$2" == "configure" ];then
	echo "Create a mysql password"
	dpkg-reconfigure mysql-server
	echo "Create a password for the pwrtelegram user"
	passwd pwrtelegram
	homedir=$( getent passwd "pwrtelegram" | cut -d: -f6 )
	configure
	exit
fi

# Check required executables
for f in apt-get;do
	which "$f" >/dev/null
done

if ! which wget &>/dev/null;then
	echo "Installing wget, nano and lsb-release..."
	apt-get update
	apt-get --force-yes -y install wget nano lsb-release
fi
# Install required packages
if [ ! -f /etc/apt/sources.list.d/hhvm.list ]; then
	echo "Adding hhvm repo..."
	DISTRIB_CODENAME=$(lsb_release -sc)
	source /etc/os-release
	wget -O - http://dl.hhvm.com/conf/hhvm.gpg.key | apt-key add -
	echo deb http://dl.hhvm.com/$ID "$DISTRIB_CODENAME" main > /etc/apt/sources.list.d/hhvm.list
fi

echo "Updating package list..."
apt-get update
echo "Updating packages..."
apt-get dist-upgrade --force-yes -y
echo "Installing required packages..."
apt-get -y --force-yes install hhvm
service hhvm stop
if [ "$2" == "docker" ];then
	apt-get --force-yes -y install curl libreadline-dev libconfig-dev libssl-dev lua5.2 liblua5.2-dev libevent-dev libjansson-dev libpython-dev make build-essential mediainfo wget mysql-server mysql-client automake autoconf libtool git software-properties-common python-software-properties tmux libcap2-bin << EOF


EOF
else
	apt-get --force-yes -y install curl libreadline-dev libconfig-dev libssl-dev lua5.2 liblua5.2-dev libevent-dev libjansson-dev libpython-dev make build-essential mediainfo wget mysql-server mysql-client automake autoconf libtool git software-properties-common python-software-properties tmux libcap2-bin
fi
update-rc.d hhvm defaults

if ! which ffprobe &>/dev/null;then
	echo "Installing ffmpeg..."
	[ $(lsb_release -rs | sed 's/\..*//g') == 14 ] && apt-add-repository ppa:mc3man/trusty-media
	apt-get update
	apt-get install ffmpeg --force-yes -y
	which ffprobe >/dev/null

fi

if ! which composer &>/dev/null;then
	echo "Installing composer..."
	curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer
	which composer >/dev/null
fi

if ! which caddy &>/dev/null;then
	echo "Installing caddy..."
	wget -O - https://getcaddy.com | bash -s cors,git,realip,upload,cloudflare
	setcap cap_net_bind_service=+ep /usr/local/bin/caddy
	which caddy >/dev/null
fi

echo "Cleaning up..."
apt-get clean

# Check whether username exists
if ! grep -qE '^pwrtelegram:' /etc/passwd; then
	echo "Creating pwrtelegram user..."
	adduser pwrtelegram << EOF
pwrtelegram
pwrtelegram
PWRTelegram



y

EOF
fi
homedir=$( getent passwd "pwrtelegram" | cut -d: -f6 )

if [ -d $homedir/pwrtelegram ]; then
	[ "$1" == "docker" ] && answer=y || read -p "The pwrtelegram directory already exists. Do you whish to delete it and restart the installation (y/n)? " answer
	[[ $answer =~ ^([yY][eE][sS]|[yY])$ ]] && rm -rf $homedir/pwrtelegram || exit 1
fi

echo "Installing pwrtelegram in $homedir/pwrtelegram..."
cd $homedir
pwrexec git clone --recursive https://github.com/pwrtelegram/pwrtelegram-backend $homedir/pwrtelegram

echo "Configuring hhvm..."
cd $homedir/pwrtelegram/
service hhvm stop
cp -a hhvm/* /etc/hhvm/
sed 's/www-data/pwrtelegram/g' -i /etc/init.d/hhvm
chown pwrtelegram:pwrtelegram -R /var/run/hhvm/
update-rc.d hhvm defaults
systemctl daemon-reload
service hhvm restart

cd $homedir/pwrtelegram/
pwrexec $homedir/pwrtelegram/update.sh

if [ "$1" !== "docker" ];then
	configure
fi

exit 0
