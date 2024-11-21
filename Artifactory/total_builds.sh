#!/bin/bash

# Artifactory credentials and URL
ARTIFACTORY_URL="http://localhost:8081/artifactory"
ARTIFACTORY_USER="admin"
ARTIFACTORY_PASSWORD="PASSWORD_HERE"

# Fetch all build names
build_names=$(curl -su "$ARTIFACTORY_USER:$ARTIFACTORY_PASSWORD" \
  -X GET "$ARTIFACTORY_URL/api/build" | jq -r '.builds[].uri' | sed 's|^/||')

# Loop through each build name
echo "Build Name | Total Builds"
echo "--------------------------"
for build_name in $build_names; do
  # Fetch build numbers for the current build
  total_builds=$(curl -su "$ARTIFACTORY_USER:$ARTIFACTORY_PASSWORD" \
    -X GET "$ARTIFACTORY_URL/api/build/$build_name" | jq -r '.buildsNumbers[].uri' | wc -l)

  # Output build name and total build count
  echo "$build_name | $total_builds"
done