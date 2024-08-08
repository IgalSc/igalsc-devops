# This script combines the request_certificates csv file 
# with the Cloudflare Zone IDs, in order to 
# update the corresponding DNS settings
#!/bin/bash

CF_API_KEY="API_KEY"

# Function to get Zone ID for a domain
get_zone_id() {
    domain=$1
    api_url="https://api.cloudflare.com/client/v4/zones?name=${domain}"
    headers="Authorization: Bearer ${CF_API_KEY}"
    response=$(curl -s -X GET "${api_url}" -H "${headers}")
    zone_id=$(echo "${response}" | jq -r '.result[0].id')
    echo "${zone_id}"
}

# Read original CSV file
input_file="certificate_details.csv"
output_file="certificate_details_with_zone.csv"

# Create a new CSV file with Zone IDs
echo "Domain Name,SANs,CNAME Name,CNAME Value,Zone ID" > "${output_file}"
tail -n +2 "${input_file}" | while IFS=, read -r domain_name sans cname_name cname_value; do
    zone_id=$(get_zone_id "${domain_name}")
    if [ -n "${zone_id}" ]; then
        echo "${domain_name},${sans},${cname_name},${cname_value},${zone_id}" >> "${output_file}"
    else
        echo "Failed to get Zone ID for ${domain_name}"
    fi
done

