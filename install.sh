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

This program is created to run on debian, it might support ubuntu.
"
pwrexec() { su pwrtelegram -c "$*"; };

tmpdir=/tmp/pwrtelegram_tmp

# Check required executables
for f in apt-get;do
	which "$f" >/dev/null
done

if ! which wget &>/dev/null;then
	echo "Installing wget..."
	apt-get update
	apt-get -y install wget
fi
# Install required packages
if [ ! -f /etc/apt/sources.list.d/hhvm.list ]; then
	echo "Adding hhvm repo..."
	source /etc/lsb-release
	wget -O - http://dl.hhvm.com/conf/hhvm.gpg.key | apt-key add -
	echo deb http://dl.hhvm.com/debian "$DISTRIB_CODENAME" main > /etc/apt/sources.list.d/hhvm.list
fi

echo "Updating package list..."
apt-get update
echo "Updating packages..."
apt-get dist-upgrade -y
echo "Installing required packages..."
apt-get -y install curl libreadline-dev libconfig-dev libssl-dev lua5.2 liblua5.2-dev libevent-dev libjansson-dev libpython-dev make build-essential mediainfo wget mysql-server mysql-client automake autoconf libtools hhvm git php5-curl php5-cli php5-json php5-mcrypt php5-mysql php5-readline php5-xmlrpc software-properties-common python-software-properties cut tmux


sudo update-rc.d hhvm defaults

if ! which ffprobe &>/dev/null;then
	echo "Installing ffmpeg..."
	echo "deb http://mirror.optus.net/deb-multimedia/ stable main
deb-src http://mirror.optus.net/deb-multimedia/ stable main">/etc/apt/sources.list.d/deb-multimedia.list
	apt-get update
	apt-get install deb-multimedia-keyring ffmpeg -y
	which ffprobe >/dev/null

fi

if ! which composer &>/dev/null;then
	echo "Installing composer..."
	curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer
	which composer >/dev/null
fi

if ! which caddy &>/dev/null;then
	echo "Installing caddy..."
	wget -O - https://getcaddy.com | bash -s cors,git,jsonp,mailout,realip,upload
	setcap cap_net_bind_service=+ep /usr/bin/caddy
	which caddy >/dev/null
fi

# Check whether username exists

if ! grep -qE '^pwrtelegram:' /etc/passwd; then
	echo "Creating pwrtelegram user..."
	adduser pwrtelegram
fi

homedir=$( getent passwd "pwrtelegram" | cut -d: -f6 )

if [ -d $homedir/pwrtelegram ]; then
	read -p "The pwrtelegram directory already exists. Do you whish to delete it and restart the installation (y/n)?" answer
	[[ $answer =~ ^([yY][eE][sS]|[yY])$ ]] && rm -r $homedir/pwrtelegram || exit 1
fi

echo "Cloning pwrtelegram in $homedir/pwrtelegram..."
pwrexec git clone https://github.com/pwrtelegram/pwrtelegram $homedir/pwrtelegram --recursive

echo "Installing tg-cli..."
cd $homedir/pwrtelegram/tg
./configure
make
make install
cp -a bin/* /usr/bin/

echo "Configuring hhvm..."
cd $homedir/pwrtelegram/
cp -a hhvm/* /etc/hhvm/
chown pwrtelegram:pwrtelegram -R /var/run/hhvm/
service hhvm restart

echo "Please enter your database connection details now."
read -p "Username: " username
read -p "Password: " password

echo "Installing database..."
cd $homedir/pwrtelegram/
mysql -u$username -p$password -e 'DROP DATABASE IF EXISTS `pwrtelegram`; CREATE DATABASE `pwrtelegram`;'
mysql -u$username -p$password < db.sql
cp dummy_db_connect.php db_connect.php
sed -i 's/user/'$username'/g;s/pass/'$password'/g' db_connect.php

cd $homedir/pwrtelegram
read -p "Type the domain name you intend to use for the main pwrtelegram API server (defaults to api.pwrtelegram.xyz): " api
[ "$api" == "" ] && api="api.pwrtelegram.xyz"
read -p "Type the domain name you intend to use for the beta pwrtelegram API server: " beta
[ "$beta" == "" ] && beta="beta.pwrtelegram.xyz"
read -p "Type the domain name you intend to use for the pwrtelegram storage server: " storage
[ "$storage" == "" ] && storage="storage.pwrtelegram.xyz"

echo "Configuring pwrtelegram..."
sed -i 's/api\.pwrtelegram\.xyz/'$api'/g;s/beta\.pwrtelegram\.xyz/'$beta'/g;s/storage\.pwrtelegram\.xyz/'$storage'/g' Caddyfile storage_url.php
pwrexec git clone https://github.com/pwrtelegram/pwrtelegram $homedir/pwrtelegram/beta

echo "That's it, pretty much!
You have configured PWRTelegram in the following way:
Main API server (syncs with pwrtelegram github repo automatically every minute to stay updated): $api
Beta API server (local clone of the PWRTelegram repository that you can use to test new features and debug the API without touching the main API): $beta
Storage server (script that serves files downloaded by the PWRTelegram API): $storage

Now you have to complete the installation by doing the following things:

1.

Edit $homedir/pwrtelegram/Caddyfile to disable or change the source repo of the PWRTelegram main API.

2.

Configure tg-cli by running telegram-cli as user pwrtelegram.

3.

Setup the storage server by setting up a CDN on the $storage domain name and create a new ssl certificate (use Cloudflare or Let's encrypt) and place the certificate in $homedir/keys/storage.cert and the key in $homedir/keys/storage.key.
To avoid creating a certificate and setting up a CDN enable automatic tls in the Caddyfile entry for $storage.

tls you@domain.com

4.

Once you have finished making your changes start the API with
$homedir/pwrtelegram/start_stop.sh start

5.

Star, watch and submit pull requests to the repositories of this project (https://github.com/pwrtelegram), subscribe to the official PWRTelegram channel (https://telegram.me/pwrtelegram), join the official PWRTelegram chat (https://telegram.me/pwrtelegramgroup), follow the official PWRTelegram account on Twitter (https://twitter.com/PWRTelegram).
Follow the creator (Daniil Gentili, https://daniil.it) on github (https://github.com/danog), contact him on Telegram (https://telegram.me/danogentili) or on Twitter (https://twitter.com/DaniilGentili)

And (optional but recommended) support the developer with a donation @ https://paypal.me/danog :)

Dropping you to a shell as user pwrtelegram...
"
su pwrtelegram
echo 'Bye!'
exit 0
