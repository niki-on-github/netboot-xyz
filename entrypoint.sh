#!/bin/sh
if [ -z "${NETWORK_IP}" ]; then
    echo "ERROR: NETWORK_IP env variable is not set"
    sleep 5
    exit 1
fi
if [ -n "${INTERFACE}" ]; then
    echo "interface=${INTERFACE}" >> /etc/dnsmasq.conf
    echo "interface=${INTERFACE}"
fi
sed -i "s/{NETWORK_IP}/${NETWORK_IP}/g" /etc/dnsmasq.conf
echo "start dnsmasq for network=${NETWORK_IP}"
/usr/sbin/dnsmasq -k --log-facility=-
