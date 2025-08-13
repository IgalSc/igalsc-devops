#!/bin/bash

# S3 Glacier Restore Script
# Efficiently restores S3 objects from Glacier storage using AWS CLI
# have the list of S3 URLs in a text file (one per line), named matched_assets.txt
# Usage example:
# ./glacier_retrieve.sh -p zonetv -j 2 -b 10 -w 1.0 matched_assets.txt

set -euo pipefail

# Default configuration
MAX_PARALLEL=${MAX_PARALLEL:-10}
BATCH_SIZE=${BATCH_SIZE:-50}
DELAY_BETWEEN_BATCHES=${DELAY_BETWEEN_BATCHES:-0.1}
RESTORE_DAYS=${RESTORE_DAYS:-7}
RESTORE_TIER=${RESTORE_TIER:-Standard}  # Standard, Expedited, Bulk
AWS_PROFILE=${AWS_PROFILE:-}
RETRY_COUNT=${RETRY_COUNT:-3}
RETRY_DELAY=${RETRY_DELAY:-2}

# Counters (using temp files for parallel processing)
TEMP_DIR=$(mktemp -d)
PROCESSED_FILE="$TEMP_DIR/processed"
RESTORE_INITIATED_FILE="$TEMP_DIR/restore_initiated"
ALREADY_RESTORED_FILE="$TEMP_DIR/already_restored"
NOT_IN_GLACIER_FILE="$TEMP_DIR/not_in_glacier"
ERRORS_FILE="$TEMP_DIR/errors"

# Initialize counter files
echo "0" > "$PROCESSED_FILE"
echo "0" > "$RESTORE_INITIATED_FILE"
echo "0" > "$ALREADY_RESTORED_FILE"
echo "0" > "$NOT_IN_GLACIER_FILE"
echo "0" > "$ERRORS_FILE"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="glacier_restore_$(date +%Y%m%d_%H%M%S).log"

# Cleanup function
cleanup() {
    # Only cleanup if we're the main process
    if [ "$" = "${MAIN_PID:-$}" ]; then
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Store main process ID
MAIN_PID=$

# Counter increment functions (with file locking)
increment_counter() {
    local file="$1"
    # Use file locking to prevent race conditions
    (
        flock -x 200
        local current=$(cat "$file" 2>/dev/null || echo "0")
        echo "$((current + 1))" > "$file"
    ) 200>"$file.lock"
}

get_counter() {
    local file="$1"
    cat "$file" 2>/dev/null || echo "0"
}

# Function to log messages
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() {
    log "INFO" "$*"
}

log_warn() {
    log "WARN" "${YELLOW}$*${NC}"
}

log_error() {
    log "ERROR" "${RED}$*${NC}"
}

log_success() {
    log "SUCCESS" "${GREEN}$*${NC}"
}

# Function to show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] <file_path>

Restore S3 objects from Glacier storage using AWS CLI.

Arguments:
    file_path           Path to text file containing S3 URLs (one per line)

Options:
    -p, --profile NAME  AWS profile to use
    -j, --parallel N    Maximum parallel jobs (default: ${MAX_PARALLEL})
    -b, --batch-size N  Batch size for processing (default: ${BATCH_SIZE})
    -d, --days N        Restore duration in days (default: ${RESTORE_DAYS})
    -t, --tier TIER     Restore tier: Standard|Expedited|Bulk (default: ${RESTORE_TIER})
    -w, --wait SECONDS  Delay between batches in seconds (default: ${DELAY_BETWEEN_BATCHES})
    -r, --retries N     Number of retries for failed requests (default: ${RETRY_COUNT})
    -h, --help          Show this help message

Examples:
    $0 matched_assets.txt
    $0 -p production -j 20 -b 100 matched_assets.txt
    $0 --profile dev --parallel 5 --tier Expedited matched_assets.txt
EOF
}

# Parse command line arguments
parse_args() {
    while [ $# -gt 0 ]; do
        case $1 in
            -p|--profile)
                AWS_PROFILE="$2"
                shift 2
                ;;
            -j|--parallel)
                MAX_PARALLEL="$2"
                shift 2
                ;;
            -b|--batch-size)
                BATCH_SIZE="$2"
                shift 2
                ;;
            -d|--days)
                RESTORE_DAYS="$2"
                shift 2
                ;;
            -t|--tier)
                RESTORE_TIER="$2"
                shift 2
                ;;
            -w|--wait)
                DELAY_BETWEEN_BATCHES="$2"
                shift 2
                ;;
            -r|--retries)
                RETRY_COUNT="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                if [ -z "${FILE_PATH:-}" ]; then
                    FILE_PATH="$1"
                else
                    log_error "Too many arguments"
                    usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# Check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed or not in PATH"
        exit 1
    fi
    
    # Test AWS credentials
    local aws_cmd="aws"
    if [ -n "${AWS_PROFILE}" ]; then
        aws_cmd="aws --profile ${AWS_PROFILE}"
    fi
    
    if ! ${aws_cmd} sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid for profile: ${AWS_PROFILE:-default}"
        exit 1
    fi
    
    log_info "AWS CLI check passed. Using profile: ${AWS_PROFILE:-default}"
}

# Parse S3 URL to get bucket and key
parse_s3_url() {
    local s3_url="$1"
    
    # Remove s3:// prefix and split bucket/key
    local path="${s3_url#s3://}"
    local bucket="${path%%/*}"
    local key="${path#*/}"
    
    if [ -z "$bucket" ] || [ -z "$key" ]; then
        log_error "Invalid S3 URL: $s3_url"
        return 1
    fi
    
    echo "$bucket|$key"
}

# Check object status and determine if restore is needed
check_object_status() {
    local bucket="$1"
    local key="$2"
    local aws_cmd="aws"
    
    if [ -n "${AWS_PROFILE}" ]; then
        aws_cmd="aws --profile ${AWS_PROFILE}"
    fi
    
    # Get object metadata
    local metadata
    if ! metadata=$(${aws_cmd} s3api head-object --bucket "$bucket" --key "$key" 2>/dev/null); then
        echo "NOT_FOUND"
        return 1
    fi
    
    # Check storage class
    local storage_class
    storage_class=$(echo "$metadata" | jq -r '.StorageClass // "STANDARD"')
    
    # If not in Glacier or Deep Archive, no restore needed
    if [ "$storage_class" != "GLACIER" ] && [ "$storage_class" != "DEEP_ARCHIVE" ]; then
        echo "NOT_GLACIER|$storage_class"
        return 0
    fi
    
    # Check restore status
    local restore_status
    restore_status=$(echo "$metadata" | jq -r '.Restore // empty')
    
    if [ -n "$restore_status" ]; then
        if echo "$restore_status" | grep -q 'ongoing-request="true"'; then
            echo "IN_PROGRESS|$storage_class"
            return 0
        elif echo "$restore_status" | grep -q 'ongoing-request="false"'; then
            echo "ALREADY_RESTORED|$storage_class"
            return 0
        fi
    fi
    
    echo "NEEDS_RESTORE|$storage_class"
    return 0
}

# Restore a single object
restore_object() {
    local s3_url="$1"
    local attempt=1
    local aws_cmd="aws"
    
    if [ -n "${AWS_PROFILE}" ]; then
        aws_cmd="aws --profile ${AWS_PROFILE}"
    fi
    
    # Parse S3 URL
    local bucket_key
    if ! bucket_key=$(parse_s3_url "$s3_url"); then
        increment_counter "$ERRORS_FILE"
        log_error "Invalid S3 URL: $s3_url"
        return 0  # Continue processing other files
    fi
    
    local bucket="${bucket_key%%|*}"
    local key="${bucket_key##*|}"
    
    # Retry loop
    while [ "$attempt" -le "$RETRY_COUNT" ]; do
        # Check if restore is needed
        local status_result
        if status_result=$(check_object_status "$bucket" "$key"); then
            local status="${status_result%%|*}"
            local storage_class="${status_result##*|}"
            
            case "$status" in
                "NOT_GLACIER")
                    increment_counter "$NOT_IN_GLACIER_FILE"
                    log_info "Not in Glacier ($storage_class): $s3_url"
                    return 0
                    ;;
                "IN_PROGRESS")
                    increment_counter "$ALREADY_RESTORED_FILE"
                    log_info "Restore in progress ($storage_class): $s3_url"
                    return 0
                    ;;
                "ALREADY_RESTORED")
                    increment_counter "$ALREADY_RESTORED_FILE"
                    log_info "Already restored ($storage_class): $s3_url"
                    return 0
                    ;;
                "NEEDS_RESTORE")
                    # Determine appropriate tier based on storage class
                    local tier="$RESTORE_TIER"
                    if [ "$storage_class" = "DEEP_ARCHIVE" ] && [ "$tier" = "Expedited" ]; then
                        tier="Standard"  # Expedited not available for Deep Archive
                    fi
                    
                    # Initiate restore
                    local restore_request="{\"Days\":${RESTORE_DAYS},\"GlacierJobParameters\":{\"Tier\":\"${tier}\"}}"
                    
                    if ${aws_cmd} s3api restore-object \
                        --bucket "$bucket" \
                        --key "$key" \
                        --restore-request "$restore_request" 2>/dev/null; then
                        
                        increment_counter "$RESTORE_INITIATED_FILE"
                        log_success "Restore initiated ($tier, $storage_class): $s3_url"
                        return 0
                    else
                        local exit_code=$?
                        if [ "$exit_code" -eq 254 ]; then  # AWS CLI throttling/rate limit
                            log_warn "Throttling detected for $s3_url (attempt $attempt/$RETRY_COUNT)"
                            sleep $((RETRY_DELAY * attempt))
                            attempt=$((attempt + 1))
                            continue
                        else
                            log_error "Failed to restore $s3_url (exit code: $exit_code)"
                            increment_counter "$ERRORS_FILE"
                            return 0  # Continue processing other files
                        fi
                    fi
                    ;;
            esac
        else
            local exit_code=$?
            if [ "$exit_code" -eq 254 ]; then  # Throttling
                log_warn "Throttling detected checking status for $s3_url (attempt $attempt/$RETRY_COUNT)"
                sleep $((RETRY_DELAY * attempt))
                attempt=$((attempt + 1))
                continue
            else
                log_error "Object not found: $s3_url"
                increment_counter "$ERRORS_FILE"
                return 0  # Continue processing other files
            fi
        fi
    done
    
    log_error "Max retries exceeded for: $s3_url"
    increment_counter "$ERRORS_FILE"
    return 0  # Continue processing other files
}

# Process a single URL (wrapper for parallel execution)
process_url() {
    local url="$1"
    restore_object "$url"
    increment_counter "$PROCESSED_FILE"
    
    # Progress logging every 25 files
    local processed=$(get_counter "$PROCESSED_FILE")
    if [ "$((processed % 25))" -eq 0 ]; then
        log_progress
    fi
}

# Log current progress
log_progress() {
    local processed=$(get_counter "$PROCESSED_FILE")
    local initiated=$(get_counter "$RESTORE_INITIATED_FILE")
    local already=$(get_counter "$ALREADY_RESTORED_FILE")
    local not_glacier=$(get_counter "$NOT_IN_GLACIER_FILE")
    local errors=$(get_counter "$ERRORS_FILE")
    
    log_info "Progress: ${processed} processed | Initiated: ${initiated} | Already: ${already} | Not Glacier: ${not_glacier} | Errors: ${errors}"
}

# Process a batch of URLs in parallel
process_batch() {
    local batch_file="$1"
    local batch_num="$2"
    local total_batches="$3"
    local batch_size=$(wc -l < "$batch_file")
    
    log_info "Processing batch $batch_num/$total_batches ($batch_size URLs)"
    
    # Process URLs in parallel using background jobs
    local pids=()
    local job_count=0
    
    while IFS= read -r url; do
        [ -z "$url" ] && continue
        
        # Start background job
        (
            # Ensure temp directory exists for this subprocess
            if [ ! -d "$TEMP_DIR" ]; then
                mkdir -p "$TEMP_DIR"
                echo "0" > "$PROCESSED_FILE"
                echo "0" > "$RESTORE_INITIATED_FILE"
                echo "0" > "$ALREADY_RESTORED_FILE"
                echo "0" > "$NOT_IN_GLACIER_FILE"
                echo "0" > "$ERRORS_FILE"
            fi
            
            export AWS_PROFILE="$AWS_PROFILE"
            export RESTORE_DAYS="$RESTORE_DAYS"
            export RESTORE_TIER="$RESTORE_TIER"
            export RETRY_COUNT="$RETRY_COUNT"
            export RETRY_DELAY="$RETRY_DELAY"
            export LOG_FILE="$LOG_FILE"
            export TEMP_DIR="$TEMP_DIR"
            export PROCESSED_FILE="$PROCESSED_FILE"
            export RESTORE_INITIATED_FILE="$RESTORE_INITIATED_FILE"
            export ALREADY_RESTORED_FILE="$ALREADY_RESTORED_FILE"
            export NOT_IN_GLACIER_FILE="$NOT_IN_GLACIER_FILE"
            export ERRORS_FILE="$ERRORS_FILE"
            export RED="$RED"
            export GREEN="$GREEN"
            export YELLOW="$YELLOW"
            export BLUE="$BLUE"
            export NC="$NC"
            
            process_url "$url"
        ) &
        
        local pid=$!
        pids+=($pid)
        job_count=$((job_count + 1))
        
        # Limit concurrent jobs
        if [ "$job_count" -ge "$MAX_PARALLEL" ]; then
            # Wait for any job to complete
            wait ${pids[0]}
            pids=("${pids[@]:1}")  # Remove first PID
            job_count=$((job_count - 1))
        fi
    done < "$batch_file"
    
    # Wait for remaining jobs
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # Small delay between batches
    sleep "$DELAY_BETWEEN_BATCHES"
}

# Process the file in batches
process_file() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        log_error "File not found: $file_path"
        exit 1
    fi
    
    # Count total files
    local total_files=$(wc -l < "$file_path")
    log_info "Found $total_files S3 URLs to process"
    log_info "Configuration: Profile=${AWS_PROFILE:-default}, Parallel=${MAX_PARALLEL}, BatchSize=${BATCH_SIZE}, RestoreDays=${RESTORE_DAYS}, Tier=${RESTORE_TIER}"
    
    local start_time=$(date +%s)
    local batch_num=1
    local total_batches=$(((total_files + BATCH_SIZE - 1) / BATCH_SIZE))
    
    # Split file into batches and process
    local line_num=0
    local batch_file="$TEMP_DIR/batch_${batch_num}.txt"
    
    while IFS= read -r line || [ -n "$line" ]; do
        [ -z "$line" ] && continue
        
        echo "$line" >> "$batch_file"
        line_num=$((line_num + 1))
        
        # Process batch when full or at end of file
        if [ "$((line_num % BATCH_SIZE))" -eq 0 ] || [ "$line_num" -eq "$total_files" ]; then
            process_batch "$batch_file" "$batch_num" "$total_batches"
            
            # Prepare next batch
            batch_num=$((batch_num + 1))
            batch_file="$TEMP_DIR/batch_${batch_num}.txt"
        fi
    done < "$file_path"
    
    # Final statistics
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local rate=0
    if [ "$duration" -gt 0 ]; then
        rate=$(($(get_counter "$PROCESSED_FILE") / duration))
    fi
    
    local processed=$(get_counter "$PROCESSED_FILE")
    local initiated=$(get_counter "$RESTORE_INITIATED_FILE")
    local already=$(get_counter "$ALREADY_RESTORED_FILE")
    local not_glacier=$(get_counter "$NOT_IN_GLACIER_FILE")
    local errors=$(get_counter "$ERRORS_FILE")
    
    echo
    log_info "=============================================="
    log_info "FINAL RESULTS:"
    log_info "Total processed: $processed"
    log_success "Restore initiated: $initiated"
    log_info "Already restored/in progress: $already"
    log_info "Not in Glacier storage: $not_glacier"
    if [ "$errors" -gt 0 ]; then
        log_error "Errors: $errors"
    else
        log_success "Errors: $errors"
    fi
    log_info "Processing time: ${duration}s"
    log_info "Average rate: ${rate} files/second"
    log_info "Log file: $LOG_FILE"
    log_info "=============================================="
    
    return "$errors"
}

# Signal handlers for graceful shutdown
cleanup_on_signal() {
    log_warn "Script interrupted. Waiting for background jobs to finish..."
    
    # Wait for background jobs to complete
    wait
    
    log_warn "Final stats:"
    log_progress
    
    # Cleanup
    cleanup
    exit 130
}

trap cleanup_on_signal SIGINT SIGTERM

# Main execution
main() {
    parse_args "$@"
    
    # Validate required arguments
    if [ -z "${FILE_PATH:-}" ]; then
        log_error "Missing required argument: file_path"
        usage
        exit 1
    fi
    
    # Validate restore tier
    case "$RESTORE_TIER" in
        Standard|Expedited|Bulk) ;;
        *)
            log_error "Invalid restore tier: $RESTORE_TIER (must be Standard, Expedited, or Bulk)"
            exit 1
            ;;
    esac
    
    # Check prerequisites
    check_aws_cli
    
    # Check if jq is available (needed for JSON parsing)
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install jq for JSON parsing."
        exit 1
    fi
    
    log_info "Starting S3 Glacier restore process"
    log_info "Input file: $FILE_PATH"
    
    # Process the file
    process_file "$FILE_PATH"
    local exit_code=$?
    
    # Exit with appropriate code
    if [ "$exit_code" -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi