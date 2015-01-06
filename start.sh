#!/bin/bash

for name in VARNISH_BACKEND_PORT VARNISH_BACKEND_HOST VARNISH_BACKEND_DOMAIN
do
    eval value=\$$name
    sed -i "s|{${name}}|${value}|g" /etc/varnish/default.vcl
done

varnishd -f /etc/varnish/default.vcl -s malloc,100M -a 0.0.0.0:${VARNISH_PORT}
varnishlog
