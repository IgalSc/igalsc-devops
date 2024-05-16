# Use to get the statistics for all the domains 
# for the last 7 days
#!/bin/bash

echo "setting up credentials"
ACCESS_TOKEN="Access_Token"
OUTPUT_FILE="result_table.csv"
CSV_FILE="zone.csv"

echo "calculating the dates"
# Calculate dates for the past week
end_date=$(date -u +"%Y-%m-%d")
start_date=$(date -u -v-7d +"%Y-%m-%d")

echo "getting sites and zones"
# Initialize the CSV file for domains and zone IDs
echo "Domain,ZoneID" > "$CSV_FILE"

# Function to fetch zones with pagination
fetch_zones() {
    local page=$1
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones?page=$page&per_page=50" \
         -H "Authorization: Bearer $ACCESS_TOKEN" \
         -H "Content-Type: application/json"
}

# Fetch the first page
response=$(fetch_zones 1)
total_pages=$(echo "$response" | jq -r '.result_info.total_pages')

# Process the first page
echo "$response" | jq -r '.result[] | "\(.name),\(.id)"' >> "$CSV_FILE"

# Fetch and process remaining pages if any
for (( page=2; page<=total_pages; page++ ))
do
    response=$(fetch_zones "$page")
    echo "$response" | jq -r '.result[] | "\(.name),\(.id)"' >> "$CSV_FILE"
done

echo "Fetched all zones successfully"

# Create or truncate the output file and write the CSV header
echo "Domain,Zone ID,Cached Requests,Total Requests" > "$OUTPUT_FILE"

echo "reading the domain names and zone IDs"
# Read the domain names and zone IDs from the CSV file
 while IFS=',' read -r domain zone_id; do
  # Generate the GraphQL query for the domain and date range
  query=$(jq -n \
    --arg zone_id "$zone_id" \
    --arg start_date "$start_date" \
    --arg end_date "$end_date" \
    '{query: ("{ viewer { zones(filter: { zoneTag: \"" + $zone_id + "\" }) { httpRequests1dGroups(limit: 100, filter: { date_geq: \"" + $start_date + "\", date_lt: \"" + $end_date + "\" }) { sum { cachedRequests requests } } } } }")}')
  
  # Debug: Print the generated query
  #echo "Generated GraphQL Query for domain $domain: $query"

  # Make the GraphQL request using cURL
  result=$(curl -s -X POST -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -d "$query" "https://api.cloudflare.com/client/v4/graphql")


  # Debug: Print the generated query
  #echo "Generated GraphQL Query for domain $domain: $query"
  # Debug: Print the entire API response
  #echo "API Response for domain $domain: $result"

  # Extract relevant information from the result
  cached_requests=$(echo "$result" | jq -r '.data.viewer.zones[0].httpRequests1dGroups[0].sum.cachedRequests')
  total_requests=$(echo "$result" | jq -r '.data.viewer.zones[0].httpRequests1dGroups[0].sum.requests')

  # Debug: Print the extracted data
  #echo "Extracted Data for domain $domain: Cached Requests: $cached_requests, Total Requests: $total_requests"

  # Append the result as a CSV row
  echo "$domain,$zone_id,$cached_requests,$total_requests" >> "$OUTPUT_FILE"
done < "$CSV_FILE"

echo "done"
# Print the result table
cat "$OUTPUT_FILE"
