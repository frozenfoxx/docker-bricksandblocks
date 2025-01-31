#!/usr/bin/env bash

# Variables
GITEA_CONF_PATH=${GITEA_CONF_PATH:-'/data/gitea/conf/app.ini'}
GITEA_CONTAINER=${GITEA_CONTAINER:-'gitea'}
GITEA_USER=${GITEA_USER:-'git'} # Note: must be the same as RUN_USER in ${GITEA_CONF_PATH}
TMPDIR=${TMPDIR:-'/tmp'}

# Functions

## Backup Gitea database
backup()
{
    echo "Running gitea dump command..."

    docker exec \
        -u "${GITEA_USER}" \
        -it \
        -w "${TMPDIR}" \
        $(docker ps -qf "name=^${GITEA_CONTAINER}$") \
            bash -c '/usr/local/bin/gitea dump -c "${GITEA_CONF_PATH}"'

    echo "Backup successfully completed and available within the container at ${TMPDIR}."
}

## Check for required tools
check_requirements()
{
    # Check if requirements were supplied
    if ! command -v docker ; then
        echo "docker not found!"
        exit 1
    fi
}

## Display usage information
usage()
{
    echo "Usage: [Environment Variables] backup_gitea.sh [-cghtu]"
    echo "  Environment Variables"
    echo "    GITEA_CONF_PATH              path for Gitea app.ini (default: '/data/gitea/conf/app.ini')"
    echo "    GITEA_CONTAINER              name of the Gitea container (default: 'gitea')"
    echo "    GITEA_USER                   name of the Gitea user (default: 'git')"
    echo "    TMPDIR                       temporary directory in the container (default: '/tmp')"
    echo "  Parameters"
    echo "    -c | --gitea-conf-path       path for Gitea app.ini (overrides GITEA_CONF_PATH)"
    echo "    -g | --gitea-container       name of the Gitea container (overrides GITEA_CONTAINER)"
    echo "    -u | --gitea-user            name of the Gitea user (overrides GITEA_USER)"
    echo "    -t | --tmpdir                temporary directory in the container (overrides TMPDIR)"
}

# Logic

## Argument parsing
while [[ "$1" != "" ]]; do
    case $1 in
        -c | --gitea-conf-path )      GITEA_CONF_PATH="${2}"
                                      shift
                                      ;;
        -g | --gitea-container )      GITEA_CONTAINER="${2}"
                                      shift
                                      ;;
        -h | --help )                 usage
                                      exit 0
                                      ;;
        -t | --tmpdir )               TMPDIR="${2}"
                                      shift
                                      ;;
        -u | --gitea-user )           GITEA_USER="${2}"
                                      shift
                                      ;;
        * )                           usage
                                      exit 1
    esac
    shift
done

check_requirements
backup