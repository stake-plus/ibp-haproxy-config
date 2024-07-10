#!/bin/bash

# Directory containing the configuration files
CONF_DIR="/opt/haproxy-3.0.2/etc/conf/"

# Arrays to hold the files for each relay chain
KUSAMA_FILES=()
WESTEND_FILES=()
POLKADOT_FILES=()
PASEO_FILES=()

# Iterate over the files in the directory
for file in "$CONF_DIR"/*; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")
        case "$filename" in
            *kusama*)
                KUSAMA_FILES+=("$filename")
                ;;
            *westend*)
                WESTEND_FILES+=("$filename")
                ;;
            *polkadot*)
                POLKADOT_FILES+=("$filename")
                ;;
            *paseo*)
                PASEO_FILES+=("$filename")
                ;;
        esac
    fi
done

# Sort the arrays
IFS=$'\n' sorted_kusama=($(sort <<<"${KUSAMA_FILES[*]}"))
IFS=$'\n' sorted_westend=($(sort <<<"${WESTEND_FILES[*]}"))
IFS=$'\n' sorted_polkadot=($(sort <<<"${POLKADOT_FILES[*]}"))
IFS=$'\n' sorted_paseo=($(sort <<<"${PASEO_FILES[*]}"))
unset IFS

# Print the sorted filenames
echo "Kusama Chains:"
printf "%s\n" "${sorted_kusama[@]}"
echo
echo "Westend Chains:"
printf "%s\n" "${sorted_westend[@]}"
echo
echo "Polkadot Chains:"
printf "%s\n" "${sorted_polkadot[@]}"
echo
echo "Paseo Chains:"
printf "%s\n" "${sorted_paseo[@]}"
