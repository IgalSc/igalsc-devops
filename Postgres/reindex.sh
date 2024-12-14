#!/bin/bash

# Ensure database connection parameters are set
DB_NAME=${1:-your_database_name}
DB_HOST=${2:-localhost}
DB_USER=${3:-$USER}

# Password handling
# Prefer environment variable, otherwise prompt
if [ -z "$PGPASSWORD" ]; then
    read -s -p "Enter password for database user $DB_USER: " PGPASSWORD
    echo  # new line after password prompt
    export PGPASSWORD
fi

# Set up connection options
export PGHOST="$DB_HOST"
export PGUSER="$DB_USER"
export PGDATABASE="$DB_NAME"

# Temporary file to store reindex commands
TEMP_FILE=$(mktemp)

# Generate reindex commands -- this query selects all indexes that start with 'user_'
# You can modify the query to select indexes based on your naming convention
# If you need to reindex all indexes, you can remove the WHERE clause
psql -t -c "
WITH user_indexes AS (
    SELECT indexrelname 
    FROM pg_stat_user_indexes 
    WHERE relname LIKE 'user_%'
)
SELECT 'REINDEX INDEX CONCURRENTLY ' || quote_ident(indexrelname) || ';' 
FROM user_indexes;
" > "$TEMP_FILE"

# Counter for tracking progress
total_indexes=$(wc -l < "$TEMP_FILE")
current_index=0

# Read and execute commands from the temp file
while IFS= read -r cmd
do
    if [[ -n "$cmd" ]]; then
        current_index=$((current_index + 1))
        echo "[$current_index/$total_indexes] Executing: $cmd"
        psql -c "$cmd"
    fi
done < "$TEMP_FILE"

# Clean up temporary file
rm "$TEMP_FILE"

echo "REINDEX CONCURRENTLY completed for user-related indexes."

# Unset password to clear sensitive information
unset PGPASSWORD