#!/bin/bash

# check if has root permisions
if [ "$EUID" -ne 0 ]; then
	echo "Please run as sudo user"
	exit 1
fi

# initialize and check variables
function err_arrgs () {
	printf "To use this script supply it with Public IP and domain name without www\nas folows: ./tesh.sh 10.10.10.10 example.com\n"
	exit 1
}

if [ $# -eq 0 ]; then
	printf "Error! There is no arguments!\n"
	err_arrgs
fi

if ! [[ $1 =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	printf "Error! First argument must be IP address\n"
	err_arrgs
fi

if [[ $2 =~ www\. ]]; then
	printf "Error! Second argument must be domain name WITHOUT www\n"
	err_arrgs
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# install python3
printf "Installing python and dependencies... "
apt-get -qq update > /dev/null
apt-get install -y python3 > /dev/null
apt-get install -y python3-pip python3-dev python3-setuptools > /dev/null
printf "OK\n"

printf "Installing build essentials... "
apt-get install -y build-essential libssl-dev libffi-dev > /dev/null
printf "OK\n"

# install python libs
printf "Installing python virtual environment... "
apt-get install -y python3-venv > /dev/null
python3 -m venv venv
printf "OK\n"

printf "Installing python libraries... "
source venv/bin/activate

yes | pip install wheel > /dev/null
yes | pip install gunicorn flask > /dev/null

deactivate
printf "OK\n"

# create service
printf "Creating systemctl service... "

cat << EOF >| /etc/systemd/system/cloudflare-site.service
[Unit]
Description=Gunicorn instance to serve myproject
After=network.target

[Service]
User=$(whoami)
Group=www-data
WorkingDirectory=$SCRIPT_DIR
Environment="PATH=$SCRIPT_DIR/venv/bin"
ExecStart=$SCRIPT_DIR/venv/bin/gunicorn --workers 3 --bind unix:cloudflare-site.sock -m 007 wsgi:app

[Install]
WantedBy=multi-user.target
EOF

printf "OK\n"

# start service
printf "Starting cloudflare-site service... "
systemctl start cloudflare-site.service
systemctl enable cloudflare-site.service

systemctl status cloudflare-site.service | grep active
printf "OK\n"

# install nginx
printf "Installing Nginx... "

apt-get install -y nginx > dev/null
systemctl status nginx | grep active
printf "OK\n"

# cofigure nginx
printf "Configuring Nginx... "

cat << EOF >| /etc/nginx/sites-available/cloudflare-site
server {
    listen 80;
    server_name $1 web.$2 app.$2;

    root $SCRIPT_DIR/;

    location /static/ {
        try_files \$uri \$uri/ @gunicorn;
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:$SCRIPT_DIR/cloudflare-site.sock;
    }

    location @gunicorn {
        include proxy_params;
        proxy_pass http://unix:$SCRIPT_DIR/cloudflare-site.sock;
    }
}
EOF

ln -s /etc/nginx/sites-available/cloudflare-site /etc/nginx/sites-enabled
nginx -t
systemctl restart nginx
printf "OK\n"

# done
echo "HTTP service is configured. Acces the site at http://$1 or http://web.$2 or http://app.$2"
