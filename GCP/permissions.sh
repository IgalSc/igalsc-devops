#!/bin/sh
# Define variables
PROJECT_ID='{PROJECT_ID}'
SERVICE_ACCOUNT_EMAIL='gmail-backup-service-account@{PROJECT_ID}.iam.gserviceaccount.com'

# Assign Project Viewer role
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/viewer"

# Assign Storage Object Admin role
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/storage.objectAdmin"

# Assign Directory Reader role
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/admin.directory.user.readonly"

# Assign Gmail Readonly role
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/gmail.readonly"