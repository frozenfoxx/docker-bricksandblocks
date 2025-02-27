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
    ## Find all YAML files recursively
    find "${COMPOSE_DIR}" -type f -name '*.yml' | while read -r YAML_ORIG_FILE; do
    
        # Set the name of the merged file to the input file
        YAML_MERGED_FILE="${YAML_ORIG_FILE}"

        # Rename the input file to show it's been read
        mv "${YAML_ORIG_FILE}" "${YAML_ORIG_FILE}.read"

        # Use yq to merge library YAML files with the given YAML file
        yq eval-all '. as $item ireduce ({}; . * $item )' "${YAML_ORIG_FILE}.read" "${LIB_DIR}/*.yml" > "${YAML_OUTPUT_FILE}"
    
        echo "Created ${YAML_OUTPUT_FILE}"
    done
}

# Logic

check_requirements
export_vars
merge_yaml
unset_vars
