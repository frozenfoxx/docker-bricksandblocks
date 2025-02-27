#!/usr/bin/env bash

# Variables
ROOT_DIR=${ROOT_DIR:-'.'}
COMPOSE_DIR="${ROOT_DIR}/compose"
LIB_FILES=$(find "${ROOT_DIR}/lib" -type f -name '*.yml')
TEMP_COMPOSE_FILE=$(mktemp)

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

# Merge YAML files
merge_yaml() {
    local output_file="$1"
    shift
    local files=("$@")

    # Concatenate YAML files with document separator
    {
        for file in "${files[@]}"; do
            cat "${file}"
            echo -e "\n---\n"
        done
    } | yq eval '.' - > "${output_file}"

    cat "${files[@]}" | yq eval '.' - > "${output_file}"
}

# Merge library files into each compose file
merge()
{    
    # Merge library YAML files into each compose YAML file
    for COMPOSE_FILE in $(find "${COMPOSE_DIR}" -type f -name '*.yml'); do

        # Collect all files to merge, starting with lib files first
        MERGE_FILES=("${LIB_FILES}" "${COMPOSE_FILE}")
        
        # Merge into the temporary compose file
        merge_yaml "${TEMP_COMPOSE_FILE}" "${MERGE_FILES[@]}"

        # Overwrite the original compose file
        mv "${TEMP_COMPOSE_FILE}" "${COMPOSE_FILE}"
    done

    echo "Library files merged into compose files"
}

# Logic
check_requirements
export_vars
merge
unset_vars
