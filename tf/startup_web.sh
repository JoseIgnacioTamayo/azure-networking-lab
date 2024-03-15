#!/bin/bash

mkdir /var/www
cat <<EOF > /var/www/webserver.py
# Python 3 server example
# https://pythonbasics.org/webserver

from http.server import BaseHTTPRequestHandler, HTTPServer
import time
import sys
 
hostName = "$(hostname)"

class MyServer(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        self.wfile.write(bytes("<html><head><title> %s </title></head>" % hostName, "utf-8"))
        self.wfile.write(bytes("<body>", "utf-8"))
        self.wfile.write(bytes("<p>Request: %s</p>" % self.requestline, "utf-8"))
        self.wfile.write(bytes("<p>Client: %s</p>" % self.client_address, "utf-8"))
        self.wfile.write(bytes("</body></html>", "utf-8"))

if __name__ == "__main__":   
    if len(sys.argv) != 2:
        raise ValueError('Missing Port to liste to.')
    serverPort = int(sys.argv[1])
    webServer = HTTPServer((hostName, serverPort), MyServer)
    print("Server started http://%s:%s" % (hostName, serverPort))
    try:
        webServer.serve_forever()
    except KeyboardInterrupt:
        pass
    webServer.server_close()
    print("Server stopped.")
EOF

python3 /var/www/webserver.py 8080 &
python3 /var/www/webserver.py 8081 &
python3 /var/www/webserver.py 8082 &
