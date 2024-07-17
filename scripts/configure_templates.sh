#!/usr/bin/env bash

# Variables
ROOT_DIR=${ROOT_DIR:-'.'}
HOSTNAME=$(/usr/bin/hostname)

# Functions

## Export variables to replace in the templates
export_vars()
{
    export HOSTNAME
    export ROOT_DIR
}

## Unset variables for safety
unset_vars()
{
    unset HOSTNAME
    unset ROOT_DIR
}

## Deploy templates
deploy_templates()
{
    ## Find all .yml.tmpl files in the repository recursively
    find "${ROOT_DIR}" -type f -name '*.yml.tmpl' | while read -r TMPL_FILE; do
    
        # Define the output file name by removing the .tmpl extension
        YAML_FILE="${TMPL_FILE%.tmpl}"
    
        # Use envsubst to replace variables in the .tmpl file and create the .yaml file
        envsubst < "${TMPL_FILE}" > "${YAML_FILE}"
    
        echo "Created ${YAML_FILE}"
    done
}

# Logic

export_vars
deploy_templates
unset_vars
