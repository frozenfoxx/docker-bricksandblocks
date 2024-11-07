#!/usr/bin/env bash

# Variables
ROOT_DIR=${ROOT_DIR:-'.'}
QBITTORRENT_TOR_PORT=""

# Functions

## Deploy stack
deploy_stack()
{
    # Deploy Gluetun VPN
    docker compose -f compose/gluetun.yml up

    # Check for the forwarded port
    while [[ ! $(docker exec -it gluetun_protonvpn cat /tmp/gluetun/forwarded_port) ]];
    do
      echo "Forwarded port not found, sleeping..."
      sleep 2
    done

    # Set forwading port
    QBITTORRENT_TOR_PORT="$(docker exec -it gluetun_protonvpn cat /tmp/gluetun/forwarded_port)"
    
    echo "Port found! Forwarding ${QBITTORRENT_TOR_PORT}, starting BitTorrent..."
    QBITTORRENT_TOR_PORT="${QBITTORRENT_TOR_PORT}" docker compose -f compose/qbittorrent.yml
}

# Logic

deploy_stack
