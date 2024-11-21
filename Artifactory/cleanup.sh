#script for the Artifactory OSS version to delete old artifacts from all repositories
#keeping only the 10 most recent artifacts in each path
#!/bin/bash

# Artifactory credentials and URL
ARTIFACTORY_URL="http://localhost:8081/artifactory"
ARTIFACTORY_USER="admin"
ARTIFACTORY_PASSWORD="PASSWORD_HERE"

# Fetch all repositories
repositories=$(curl -su "$ARTIFACTORY_USER:$ARTIFACTORY_PASSWORD" -X GET \
  "$ARTIFACTORY_URL/api/repositories" | jq -r '.[].key')

# Iterate through each repository
for repo in $repositories; do
  echo "Processing repository: $repo"

  # Fetch all paths within the repository
  paths=$(curl -su "$ARTIFACTORY_USER:$ARTIFACTORY_PASSWORD" -X POST \
    -H "Content-Type: text/plain" \
    "$ARTIFACTORY_URL/api/search/aql" \
    -d "items.find({\"repo\":\"$repo\"}).include(\"path\")" | \
    jq -r '.results[].path' | sort -u)

  # Iterate through each path
  for path in $paths; do
    echo "  Processing path: $path"

    # Fetch all artifacts within the path
    artifacts=$(curl -su "$ARTIFACTORY_USER:$ARTIFACTORY_PASSWORD" -X POST \
      -H "Content-Type: text/plain" \
      "$ARTIFACTORY_URL/api/search/aql" \
      -d "items.find({\"repo\":\"$repo\",\"path\":\"$path\"}).include(\"name\",\"created\")" | \
      jq -r '.results | sort_by(.created) | .[].name')

    # Count total artifacts
    total_artifacts=$(echo "$artifacts" | wc -l)
    echo "    Total artifacts: $total_artifacts"

    # Skip if there are 10 or fewer artifacts
    if [ "$total_artifacts" -le 10 ]; then
      echo "    Skipping: Less than or equal to 10 artifacts"
      continue
    fi

    # Get artifacts to delete (all but the 10 most recent ones)
    artifacts_to_delete=$(echo "$artifacts" | head -n -10)

    # Delete artifacts
    for artifact in $artifacts_to_delete; do
      echo "    Deleting artifact: $artifact"
      curl -su "$ARTIFACTORY_USER:$ARTIFACTORY_PASSWORD" -X DELETE \
        "$ARTIFACTORY_URL/$repo/$path/$artifact"
    done
  done
done

echo "Cleanup complete."