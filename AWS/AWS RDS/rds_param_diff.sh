# A script to compare custom RDS parameter group vs default parameter group for a given RDS instance.
# It will list all parameters that differ from the default values.
# Usage
# ./rds_param_diff.sh myprofile us-east-1 my-source-pg

#!/usr/bin/env bash
set -euo pipefail

PROFILE="${1:?AWS profile required}"
REGION="${2:?AWS region required}"
SOURCE_PG_NAME="${3:?Source parameter group name required}"

AWS="aws --profile $PROFILE --region $REGION"

echo "Using profile: $PROFILE"
echo "Region:        $REGION"
echo "Source PG:     $SOURCE_PG_NAME"
echo

# 1) Get family of the source group (e.g., postgres13)
FAMILY="$($AWS rds describe-db-parameter-groups \
  --db-parameter-group-name "$SOURCE_PG_NAME" \
  --query 'DBParameterGroups[0].DBParameterGroupFamily' \
  --output text)"

# 2) Find the default parameter group name for that family
DEFAULT_PG_NAME="$($AWS rds describe-db-parameter-groups \
  --query "DBParameterGroups[?DBParameterGroupFamily=='$FAMILY' && IsDefault==\`true\`].DBParameterGroupName | [0]" \
  --output text)"

echo "Family:        $FAMILY"
echo "Default PG:    $DEFAULT_PG_NAME"
echo

# Helper function to dump all parameters
dump_params () {
  local PG="$1"
  local MARKER=""

  while :; do
    if [[ -n "$MARKER" ]]; then
      RESP="$($AWS rds describe-db-parameters \
        --db-parameter-group-name "$PG" \
        --marker "$MARKER")"
    else
      RESP="$($AWS rds describe-db-parameters \
        --db-parameter-group-name "$PG")"
    fi

    echo "$RESP" | jq -c '.Parameters[]
      | {ParameterName, ParameterValue, ApplyMethod}'

    MARKER="$(echo "$RESP" | jq -r '.Marker // empty')"
    [[ -z "$MARKER" ]] && break
  done
}

echo "Dumping parameters..."
dump_params "$SOURCE_PG_NAME"  | sort > /tmp/source_params.jsonl
dump_params "$DEFAULT_PG_NAME" | sort > /tmp/default_params.jsonl

# Reduce to name=value for diff
jq -r '.ParameterName + "=" + (.ParameterValue // "")' /tmp/source_params.jsonl  | sort > /tmp/source_kv.txt
jq -r '.ParameterName + "=" + (.ParameterValue // "")' /tmp/default_params.jsonl | sort > /tmp/default_kv.txt

echo
echo "===== Parameters Different From Default (Your Overrides) ====="
comm -23 /tmp/source_kv.txt /tmp/default_kv.txt

echo
echo "Done."
