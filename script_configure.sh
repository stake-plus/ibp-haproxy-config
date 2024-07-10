#!/bin/bash

# Define the URLs for the JSON data and output files
JSON_URL="https://raw.githubusercontent.com/ibp-network/config/main/services_rpc.json"
SUBDOMAIN_MAP_FILE="/opt/haproxy-3.0.2/etc/service_dns_map.txt"
PATH_MAP_FILE="/opt/haproxy-3.0.2/etc/service_path_map.txt"
SERVICE_WSP2P_MAP_FILE="/opt/haproxy-3.0.2/etc/service_wsp2p_map.txt"
BACKENDS_DIR="/opt/haproxy-3.0.2/etc/conf"

# Delete the existing services_rpc.json file if it exists
rm -f services_rpc.json

# Fetch the JSON data
curl -s $JSON_URL -o services_rpc.json

# Initialize the map files
mkdir -p $BACKENDS_DIR
echo -n "" > $SUBDOMAIN_MAP_FILE
echo -n "" > $PATH_MAP_FILE
echo -n "" > $SERVICE_WSP2P_MAP_FILE

# Parse the JSON and generate the map files
jq -r 'to_entries | .[] | "\(.key) \(.value.Providers | to_entries | .[] | .value.RpcUrls[])"' services_rpc.json | while IFS=$' ' read -r network url; do
  # Remove the scheme (e.g., wss://, https://, http://) from the URL
  clean_url=$(echo $url | sed -E 's|^[a-zA-Z]+://||')

  # Extract the subdomain or path from the URL
  if [[ $clean_url == */* ]]; then
    # It's a path-based URL
    path=$(echo $clean_url | grep -oP '/[^/]+')
    echo "$path ${network,,}-backend" >> $PATH_MAP_FILE
  else
    # It's a subdomain-based URL
    subdomain=$(echo $clean_url | grep -oP '^[^.]+')
    echo "$clean_url ${network,,}-backend" >> $SUBDOMAIN_MAP_FILE
  fi

  # Update the service_wsp2p_map.txt file if the entry doesn't exist already
  if ! grep -q "${network,,}.boot.stake.plus" $SERVICE_WSP2P_MAP_FILE; then
    echo "${network,,}.boot.stake.plus ${network,,}" >> $SERVICE_WSP2P_MAP_FILE
  fi
done

# Remove duplicate lines in the files
sort -u -o $SUBDOMAIN_MAP_FILE $SUBDOMAIN_MAP_FILE
sort -u -o $PATH_MAP_FILE $PATH_MAP_FILE
sort -u -o $SERVICE_WSP2P_MAP_FILE $SERVICE_WSP2P_MAP_FILE

# Function to determine the filename prefix based on the network name
get_filename_prefix() {
  local network=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  if [[ $network == *paseo* ]]; then
    echo "15"
  elif [[ $network == *westend* ]]; then
    echo "20"
  elif [[ $network == *kusama* ]]; then
    echo "25"
  elif [[ $network == *polkadot* ]]; then
    echo "30"
  else
    echo "20"  # Default prefix if no specific match is found
  fi
}

# Create backend configuration files
jq -r 'keys[]' services_rpc.json | while read -r network; do
  prefix=$(get_filename_prefix "$network")
  backend_file="$BACKENDS_DIR/${prefix}-${network,,}.cfg"
  if [[ ! -f $backend_file ]]; then
    cat <<EOF > "$backend_file"
backend ${network,,}-backend
  mode http
  balance leastconn
  server ${network,,}-rpc-1 1.1.1.1:10000 check inter 2s maxconn 10000
  server ${network,,}-rpc-2 2.2.2.2:10000 check inter 2s maxconn 10000

backend ${network,,}-wsp2p-para-1
  mode http
  server ${network,,}-wsp2p-1 1.1.1.1:30332 check inter 2s maxconn 1000

backend ${network,,}-wsp2p-relay-1
  mode http
  server ${network,,}-wsp2p-1 1.1.1.1:30334 check inter 2s maxconn 1000

backend ${network,,}-wsp2p-para-2
  mode http
  server ${network,,}-wsp2p-2 2.2.2.2:30332 check inter 2s maxconn 1000

backend ${network,,}-wsp2p-relay-2
  mode http
  server ${network,,}-wsp2p-2 2.2.2.2:30334 check inter 2s maxconn 1000

EOF
    echo "Created new config file for ${network}"
  fi
done
