#!/usr/bin/env bash

# Variables
DATA_PREFIX=${DATA_PREFIX:-'/data'}
LOCAL_PREFIX=${LOCAL_PREFIX:-'/local'}

# Functions

## Backup local prefixes to the data host
backup()
{
    echo "Backing up ${LOCAL_PREFIX} to ${DATA_PREFIX}..."

    for dir in $(ls "${LOCAL_PREFIX}"); do
      echo "Processing ${LOCAL_PREFIX}/${dir}..."
      rsync -avP --delete ${LOCAL_PREFIX}/${dir} ${DATA_PREFIX}/
    done
}

## Check for required tools
check_requirements()
{
    # Check if requirements were supplied
    if ! command -v rsync ; then
        echo "rsync not found!"
        exit 1
    fi
}

## Display usage information
usage()
{
    echo "Usage: [Environment Variables] backup_local.sh [-dlh]"
    echo "  Environment Variables"
    echo "    DATA_PREFIX              path for data host mounts (default: '/data')"
    echo "    LOCAL_PREFIX             path for local mounts (default: '/local')"
    echo "  Parameters"
    echo "    -d | --data-prefix       path for data host mounts (overrides DATA_PREFIX)"
    echo "    -l | --local-prefix      path for local mounts (overrides LOCAL_PREFIX)"
}

# Logic

## Argument parsing
while [[ "$1" != "" ]]; do
    case $1 in
        -d | --data-prefix )          LOCAL_PREFIX="${2}"
                                      shift
                                      ;;
        -l | --local-prefix )         DATA_PREFIX="${2}"
                                      shift
                                      ;;
        -h | --help )                 usage
                                      exit 0
                                      ;;
        * )                           usage
                                      exit 1
    esac
    shift
done

check_requirements
backup