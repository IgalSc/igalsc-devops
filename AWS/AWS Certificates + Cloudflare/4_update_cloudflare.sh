#!/bin/bash

CF_API_KEY="API_KEY"  # use global API key
EMAIL='email@here'                 # email address of the account that is using the global API key
input_file="certificate_details_with_zone.csv"

# Read the input file line by line
while IFS=, read -r domain sans cname_name cname_value zone_id; do
  # Skip the header row and empty lines
  if [[ "$domain" == "Domain Name" || -z "$zone_id" ]]; then
    continue
  fi

  # Remove newline character from zone_id
  zone_id=$(echo "$zone_id" | tr -d '\r')

  # Update Cloudflare for the domain with the CNAME name/value pair
  data="{\"type\":\"CNAME\",\"name\":\"${cname_name}\",\"content\":\"${cname_value}\",\"ttl\":120,\"proxied\":false}"
  echo "Updating Cloudflare for ${cname_name}.${domain} in zone ${zone_id}"
  echo "Data: ${data}"
  response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
              -H "Content-Type: application/json" \
              -H "X-Auth-Email: $EMAIL" \
              -H "X-Auth-Key: ${CF_API_KEY}" \
              --data "${data}")

  # Check for errors in the response
  http_status=$(echo "$response" | jq -r '.success')
  if [[ "$http_status" != "true" ]]; then
    echo "Failed to update Cloudflare for ${cname_name}.${domain}."
    echo "Error response from Cloudflare API:"
    echo "$response"
  fi
  # Sleep for 10 second between requests to avoid throttling
  sleep 10
done < "$input_file"