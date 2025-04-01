#!/bin/bash

# Configuration
USER="your-username"
WORKSPACE="your-workspace"
APP_PASSWORD="your-app-password"

AWS_ACCESS_KEY_ID_VALUE="your-access-key"
AWS_SECRET_ACCESS_KEY_VALUE="your-secret-key"

REPO_LIST=("repo1" "repo2" "repo3")  # Add repo names here

for REPO in "${REPO_LIST[@]}"; do
    echo "Adding variables to $REPO..."

    # Add AWS_ACCESS_KEY_ID (not secured)
    curl -s -X POST -u "$USER:$APP_PASSWORD" \
        -H "Content-Type: application/json" \
        -d "{\"key\": \"AWS_ACCESS_KEY_ID\", \"value\": \"$AWS_ACCESS_KEY_ID_VALUE\", \"secured\": false}" \
        "https://api.bitbucket.org/2.0/repositories/$WORKSPACE/$REPO/pipelines_config/variables/"

    # Add AWS_SECRET_ACCESS_KEY (secured)
    curl -s -X POST -u "$USER:$APP_PASSWORD" \
        -H "Content-Type: application/json" \
        -d "{\"key\": \"AWS_SECRET_ACCESS_KEY\", \"value\": \"$AWS_SECRET_ACCESS_KEY_VALUE\", \"secured\": true}" \
        "https://api.bitbucket.org/2.0/repositories/$WORKSPACE/$REPO/pipelines_config/variables/"

    echo "Done with $REPO"
done