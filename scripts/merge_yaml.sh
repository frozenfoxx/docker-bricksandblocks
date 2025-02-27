#!/usr/bin/env bash

# Variables
ROOT_DIR=${ROOT_DIR:-'.'}
COMPOSE_FILES=$(find "${ROOT_DIR}/compose" -type f -name '*.yml')
LIB_FILES=$(find "${ROOT_DIR}/lib" -type f -name '*.yml')
TEMP_COMPOSE_FILE=$(mktemp)

# Functions

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

    # Clear the output file
    > "${output_file}"

    # Concatenate files into output_file with document separators
    for file in "${files[@]}"; do
        echo -e "---\n" >> "${output_file}"
        cat "${file}" >> "${output_file}"
        echo -e "\n" >> "${output_file}"
    done
}

# Merge library files into each compose file
merge()
{    
    # Merge library YAML files into each compose YAML file
    for COMPOSE_FILE in ${COMPOSE_FILES}; do

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
