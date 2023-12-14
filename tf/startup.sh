#!/bin/bash

curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

mkdir /var/www
cd /var/www
cat <<EOF > ./index.html
Hello from $(hostname)
EOF
python3 -m http.server 8080 &
python3 -m http.server -b :: 8081 &
