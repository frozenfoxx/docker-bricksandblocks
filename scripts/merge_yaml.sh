#!/usr/bin/env bash

# Variables
ROOT_DIR=${ROOT_DIR:-'.'}
COMPOSE_DIR="${ROOT_DIR}/compose"
LIB_DIR="${ROOT_DIR}/lib"

# Functions

## Check for required tools
check_requirements()
{
    # Check if requirements were supplied
    if ! command -v yq ; then
        echo "yq not found!"
        exit 1
    fi
}

## Export variables to replace in the templates
export_vars()
{
    export ROOT_DIR
}

## Unset variables for safety
unset_vars()
{
    unset ROOT_DIR
}

## Merge YAML files
merge_yaml()
{
    # Merge library YAML files into each compose YAML file
    for YAML_FILE in $(find "${COMPOSE_DIR}" -type f -name '*.yml'); do
        # Use yq to merge library YAML files with the given YAML file
        yq -i '.' "${YAML_FILE}" "$(ls ${LIB_DIR}/*.yml)"
    done

    echo "Library files merged into compose files"
}

# Logic

check_requirements
export_vars
merge_yaml
unset_vars
