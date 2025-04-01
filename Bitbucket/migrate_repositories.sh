#!/bin/bash

# Configuration
SOURCE_USER="your-source-username"
SOURCE_WORKSPACE="zonetv"
SOURCE_APP_PASSWORD="your-source-app-password"

DEST_USER="your-destination-username"
DEST_WORKSPACE="your-destination-workspace"
DEST_APP_PASSWORD="your-destination-app-password"

SEARCH_TERM="games"
PROJECT_UUID="{$PROJECT_UUID}}"  # Include curly braces

# Paginate through results
PAGE=1

while : ; do
  echo "Fetching repositories - page $PAGE..."
  
  RESPONSE=$(curl -s -u "$SOURCE_USER:$SOURCE_APP_PASSWORD" \
    "https://api.bitbucket.org/2.0/repositories/$SOURCE_WORKSPACE?pagelen=50&page=$PAGE&q=project.uuid=\"$PROJECT_UUID\" AND name~\"$SEARCH_TERM\"&sort=-updated_on")

  REPOS=$(echo "$RESPONSE" | jq -r '.values[].slug')

  # Break if no more repos
  if [[ -z "$REPOS" ]]; then
    echo "No more repositories found."
    break
  fi

  for REPO in $REPOS; do
      echo "Migrating repository: $REPO"

      # Create new repo in destination workspace
      echo "Creating $REPO in destination workspace..."
      curl -s -X POST -u "$DEST_USER:$DEST_APP_PASSWORD" \
          -H "Content-Type: application/json" \
          -d "{\"scm\": \"git\", \"is_private\": true}" \
          "https://api.bitbucket.org/2.0/repositories/$DEST_WORKSPACE/$REPO"

      # Clone source repo with all branches
      git clone --mirror https://$SOURCE_USER:$SOURCE_APP_PASSWORD@bitbucket.org/$SOURCE_WORKSPACE/$REPO.git
      cd $REPO.git

      # Push to destination repo
      git remote add new-origin https://$DEST_USER:$DEST_APP_PASSWORD@bitbucket.org/$DEST_WORKSPACE/$REPO.git
      git push --mirror new-origin

      cd ..
      rm -rf $REPO.git
      echo "✅ Done migrating $REPO"
  done

  # Next page?
  PAGE=$((PAGE + 1))
done