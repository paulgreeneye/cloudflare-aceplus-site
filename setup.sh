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
echo "Installing python and dependencies..."
apt update
apt install python3-pip python3-dev build-essential libssl-dev libffi-dev python3-setuptools

# install python libs
apt install python3-venv
python3 -m venv venv
source venv/bin/activate

pip install wheel
pip install gunicorn flask

deactivate

# create service
echo "Creating systemctl service..."

cat << EOF >| /etc/systemd/system/cloudflare.service
[Unit]
Description=Gunicorn instance to serve myproject
After=network.target

[Service]
User=$(whoami)
Group=www-data
WorkingDirectory=$SCRIPT_DIR
Environment="PATH=$SCRIPT_DIR/venv/bin"
ExecStart=$SCRIPT_DIR/venv/bin/gunicorn --workers 3 --bind unix:cloudflare.sock -m 007 wsgi:app

[Install]
WantedBy=multi-user.target
EOF

# start service
systemctl start cloudflare.service
systemctl enable cloudflare.service

systemctl status cloudflare.service

# install nginx
echo "Installing and configuring nginx..."

apt install nginx
systemctl status nginx

# cofigure nginx
cat << EOF >| /etc/nginx/sites-available/cloudflare
server {
    listen 80;
    server_name $1 web.$2 app.$2;

    root $SCRIPT_DIR/static/;

    location / {
        try_files $uri $uri/ @gunicorn;
    }

    location @gunicorn {
        include proxy_params;
        proxy_pass http://unix:$SCRIPT_DIR/cloudflare.sock;
    }
}
EOF

ln -s /etc/nginx/sites-available/cloudflare /etc/nginx/sites-enabled
nginx -t
systemctl restart nginx

# done
echo "HTTP service is configured. Acces the site at $1 or web.$2 or app.$2"
