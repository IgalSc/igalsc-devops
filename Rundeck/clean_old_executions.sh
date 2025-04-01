#!/bin/bash

# --- CONFIGURATION ---
RUNDECK_URL="https://your-rundeck-url"      # Replace with your Rundeck URL
API_TOKEN="your_api_token"                  # Replace with your Rundeck API token
PROJECT="your_project_name"                 # Replace with your Rundeck project name
API_VERSION="48"
BATCH_SIZE=1000

# --- Calculate target date (30 days ago) ---
if date -v-30d "+%Y-%m-%d" >/dev/null 2>&1; then
  # macOS (BSD date)
  TARGET_DATE=$(date -v-30d "+%Y-%m-%d")
else
  # Linux (GNU date)
  TARGET_DATE=$(date -d "30 days ago" "+%Y-%m-%d")
fi

# --- Convert cutoff date to epoch ---
if date -d "$TARGET_DATE" +%s >/dev/null 2>&1; then
  TARGET_EPOCH=$(date -d "$TARGET_DATE" +%s)
elif date -jf "%Y-%m-%d" "$TARGET_DATE" +%s >/dev/null 2>&1; then
  TARGET_EPOCH=$(date -jf "%Y-%m-%d" "$TARGET_DATE" +%s)
else
  echo "❌ Error: Could not parse cutoff date: $TARGET_DATE"
  exit 1
fi

# --- Format for human-readable logging ---
format_unix_date() {
  if date -d "@$1" "+%Y-%m-%d %H:%M:%S" >/dev/null 2>&1; then
    date -d "@$1" "+%Y-%m-%d %H:%M:%S"
  else
    date -r "$1" "+%Y-%m-%d %H:%M:%S"
  fi
}

# --- Flags ---
DRYRUN=false
INCLUDE_MISSING=false

for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    DRYRUN=true
    echo "🧪 Running in DRY-RUN mode — no deletions will be made."
  elif [[ "$arg" == "--include-missing" ]]; then
    INCLUDE_MISSING=true
    echo "⚠️  Will delete executions with missing timestamps (use with caution)."
  fi
done

# --- Headers ---
HEADER_AUTH="X-Rundeck-Auth-Token: $API_TOKEN"
HEADER_JSON="Content-Type: application/json"

echo "🧹 Starting cleanup of executions before $TARGET_DATE..."

OFFSET=0
DELETED=0
while true; do
  echo "📦 Fetching up to $BATCH_SIZE executions (offset=$OFFSET)..."
  RESPONSE=$(curl -s -H "$HEADER_AUTH" -H "$HEADER_JSON" \
    "$RUNDECK_URL/api/$API_VERSION/project/$PROJECT/executions?max=$BATCH_SIZE&offset=$OFFSET")
          
  EXECUTIONS=$(echo "$RESPONSE" | jq -c '.executions[]?')
  COUNT=0
  STOP=false  
            
  if [ -z "$EXECUTIONS" ]; then
    echo "✅ No more executions found. Done."
    break
  fi
      
  while read -r execution; do
    ID=$(echo "$execution" | jq -r '.id')
    RAW_EPOCH=$(echo "$execution" | jq -r '."date-started".unixtime // empty')
      
    if [[ "$RAW_EPOCH" =~ ^[0-9]+$ ]]; then
      STARTED_EPOCH=$((RAW_EPOCH / 1000))   
      if [ "$STARTED_EPOCH" -lt "$TARGET_EPOCH" ]; then
        STARTED_FMT=$(format_unix_date "$STARTED_EPOCH")
  
        if [ "$DRYRUN" == true ]; then
          echo "  🧪 DRY-RUN: Would delete execution $ID (started $STARTED_FMT)"
        else
          echo -n "  ➤ Deleting execution $ID (started $STARTED_FMT)... "
          DELETE_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
            -H "$HEADER_AUTH" "$RUNDECK_URL/api/$API_VERSION/execution/$ID")
    
          if [ "$DELETE_RESPONSE" == "204" ]; then
            echo "Deleted ✅"
            DELETED=$((DELETED + 1))
          else
            echo "Failed ❌ ($DELETE_RESPONSE)"
          fi
    
          sleep 0.05
        fi
      else
        echo "  ⏩ Skipping execution $ID (newer than cutoff)"
      fi
    else
      if [ "$INCLUDE_MISSING" == true ]; then
        echo "  ⚠️  No timestamp. Deleting execution $ID anyway (include-missing)."
        if [ "$DRYRUN" == true ]; then      
          echo "  🧪 DRY-RUN: Would delete execution $ID (missing timestamp)"
        else
          DELETE_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
            -H "$HEADER_AUTH" "$RUNDECK_URL/api/$API_VERSION/execution/$ID")
          
          if [ "$DELETE_RESPONSE" == "204" ]; then
            echo "Deleted ✅"
            DELETED=$((DELETED + 1))
          else
            echo "Failed ❌ ($DELETE_RESPONSE)"
          fi
            
          sleep 0.05
        fi
      else
        echo "  ⚠️  Skipping execution $ID (missing timestamp)"
      fi
    fi
          
    COUNT=$((COUNT + 1))
  done <<< "$EXECUTIONS"
        
  OFFSET=$((OFFSET + COUNT))
done
        
echo "🎉 Cleanup complete. Deleted $DELETED old executions."