#!/usr/bin/env bash

set -o pipefail

# Variables
BACKUP_DIR=${NIGHTSCOUT_BACKUP_DIR:-"${DATA_PREFIX:-/data}/nightscout/backups"}
CONTAINER=${NIGHTSCOUT_MONGO_CONTAINER:-'nightscout-mongo'}
DATABASE=${NIGHTSCOUT_DATABASE:-'nightscout'}
RETENTION_DAYS=${NIGHTSCOUT_BACKUP_RETENTION_DAYS:-'30'}

# Functions

## Dump the Nightscout database to the data host
## A live copy of Mongo's data directory isn't consistent, so dump instead of rsync
backup()
{
    local archive
    archive="${BACKUP_DIR}/${DATABASE}-$(date +%Y%m%d-%H%M%S).archive.gz"

    echo "Dumping ${DATABASE} from ${CONTAINER} to ${archive}..."

    mkdir -p "${BACKUP_DIR}" || exit 1

    # Write to a temporary name so a failed dump never looks like a good backup
    if ! docker exec "${CONTAINER}" mongodump --quiet --db "${DATABASE}" --archive --gzip > "${archive}.partial" ; then
        echo "Dump failed!"
        rm -f "${archive}.partial"
        exit 1
    fi

    mv "${archive}.partial" "${archive}"
    echo "Backup complete, $(du -h "${archive}" | cut -f1)."
}

## Check for required tools
check_requirements()
{
    if ! command -v docker > /dev/null ; then
        echo "docker not found!"
        exit 1
    fi
}

## Remove backups older than the retention period
prune()
{
    echo "Removing backups older than ${RETENTION_DAYS} days..."

    find "${BACKUP_DIR}" -maxdepth 1 -name "${DATABASE}-*.archive.gz" -mtime +"${RETENTION_DAYS}" -print -delete
}

## Display usage information
usage()
{
    echo "Usage: [Environment Variables] backup_nightscout.sh [-bcdhr]"
    echo "  Environment Variables"
    echo "    DATA_PREFIX                        path for data host mounts (default: '/data')"
    echo "    NIGHTSCOUT_BACKUP_DIR              backup directory (default: '\${DATA_PREFIX}/nightscout/backups')"
    echo "    NIGHTSCOUT_BACKUP_RETENTION_DAYS   days of backups to keep (default: '30')"
    echo "    NIGHTSCOUT_DATABASE                Mongo database name (default: 'nightscout')"
    echo "    NIGHTSCOUT_MONGO_CONTAINER         Mongo container name (default: 'nightscout-mongo')"
    echo "  Parameters"
    echo "    -b | --backup-dir                  backup directory (overrides NIGHTSCOUT_BACKUP_DIR)"
    echo "    -c | --container                   Mongo container name (overrides NIGHTSCOUT_MONGO_CONTAINER)"
    echo "    -d | --database                    Mongo database name (overrides NIGHTSCOUT_DATABASE)"
    echo "    -r | --retention-days              days of backups to keep (overrides NIGHTSCOUT_BACKUP_RETENTION_DAYS)"
}

# Logic

## Argument parsing
while [[ "$1" != "" ]]; do
    case $1 in
        -b | --backup-dir )           BACKUP_DIR="${2}"
                                      shift
                                      ;;
        -c | --container )            CONTAINER="${2}"
                                      shift
                                      ;;
        -d | --database )             DATABASE="${2}"
                                      shift
                                      ;;
        -h | --help )                 usage
                                      exit 0
                                      ;;
        -r | --retention-days )       RETENTION_DAYS="${2}"
                                      shift
                                      ;;
        * )                           usage
                                      exit 1
    esac
    shift
done

check_requirements
backup
prune
