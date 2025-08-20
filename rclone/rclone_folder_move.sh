#!/bin/bash

# rclone Directory Move Script
# Moves all files from specified directories to another S3 account
# assuming you have rclone configured with both source and destination remotes
# check README_FIRST.txt for prerequisites and usage instructions

set -euo pipefail

# Default configuration
METHOD=${METHOD:-sync}  # sync, move, or copy
PARALLEL_TRANSFERS=${PARALLEL_TRANSFERS:-4}
CHECKERS=${CHECKERS:-8}
BANDWIDTH_LIMIT=${BANDWIDTH_LIMIT:-}
DRY_RUN=${DRY_RUN:-false}
CHECK_FIRST=${CHECK_FIRST:-true}
DELETE_EMPTY_DIRS=${DELETE_EMPTY_DIRS:-true}
DEST_BUCKET=${DEST_BUCKET:-}
PRESERVE_STRUCTURE=${PRESERVE_STRUCTURE:-true}

# Required parameters
SOURCE_REMOTE=""
DEST_REMOTE=""
SUBFOLDERS_FILE=""
SOURCE_BUCKET=""

# Counters
TOTAL_FOLDERS=0
PROCESSED_FOLDERS=0
TOTAL_FILES=0
SUCCESS_FILES=0
ERROR_FILES=0
SKIPPED_FILES=0
NOT_AVAILABLE_FILES=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Log file
LOG_FILE="rclone_folder_move_$(date +%Y%m%d_%H%M%S).log"

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() { log "INFO" "$*"; }
log_warn() { log "WARN" "${YELLOW}$*${NC}"; }
log_error() { log "ERROR" "${RED}$*${NC}"; }
log_success() { log "SUCCESS" "${GREEN}$*${NC}"; }

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS] <source_remote> <source_bucket> <dest_remote> <subfolders_file>

Move all files from specified directories to another S3 account using rclone.

Arguments:
    source_remote       Source rclone remote name (e.g., 'zonetv')
    source_bucket       Source bucket name (e.g., 'zonecloud-ooyala-ingestion')
    dest_remote         Destination rclone remote name (e.g., 'es3')
    subfolders_file     Text file containing subfolder paths (one per line)

Options:
    -m, --method METHOD     Transfer method: sync|move|copy (default: ${METHOD})
    -p, --parallel N        Parallel transfers (default: ${PARALLEL_TRANSFERS})
    -c, --checkers N        Parallel checkers (default: ${CHECKERS})
    -b, --bandwidth LIMIT   Bandwidth limit (e.g., 10M, 1G)
    --dest-bucket BUCKET    Override destination bucket name
    --no-check             Skip availability check before transfer
    --keep-dirs            Don't delete empty directories after move
    --flatten              Don't preserve directory structure (put all in root)
    --dry-run              Perform dry run without actual transfers
    -h, --help             Show this help

Transfer Methods:
    sync    - Use rclone sync source to dest, then delete source files
    move    - Use rclone move (atomic operation, recommended)
    copy    - Use rclone copy only (keeps source files)

Subfolders file format:
    dropbox/Lion Mountain TV/
    dropbox/Light Box Video/
    dropbox/Halloween Tracker/

Examples:
    $0 zonetv zonecloud-ooyala-ingestion es3 subfolders.txt
    $0 -m move -p 8 zonetv source-bucket es3 subfolders.txt
    $0 --dry-run --dest-bucket new-bucket zonetv bucket es3 subfolders.txt
    $0 --flatten zonetv bucket es3 subfolders.txt

Prerequisites:
    - rclone configured with both source and destination remotes
    - Appropriate S3 permissions on both accounts
    - Files should be restored from Glacier before running
EOF
}

# Parse command line arguments
parse_args() {
    # First pass: collect all non-option arguments
    local positional_args=()
    
    while [ $# -gt 0 ]; do
        case $1 in
            -m|--method)
                METHOD="$2"
                shift 2
                ;;
            -p|--parallel)
                PARALLEL_TRANSFERS="$2"
                shift 2
                ;;
            -c|--checkers)
                CHECKERS="$2"
                shift 2
                ;;
            -b|--bandwidth)
                BANDWIDTH_LIMIT="$2"
                shift 2
                ;;
            --dest-bucket)
                DEST_BUCKET="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-check)
                CHECK_FIRST=false
                shift
                ;;
            --keep-dirs)
                DELETE_EMPTY_DIRS=false
                shift
                ;;
            --flatten)
                PRESERVE_STRUCTURE=false
                shift
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
                positional_args+=("$1")
                shift
                ;;
        esac
    done
    
    # Assign positional arguments
    if [ ${#positional_args[@]} -ne 4 ]; then
        log_error "Expected exactly 4 arguments, got ${#positional_args[@]}: ${positional_args[*]}"
        usage
        exit 1
    fi
    
    SOURCE_REMOTE="${positional_args[0]}"
    SOURCE_BUCKET="${positional_args[1]}"
    DEST_REMOTE="${positional_args[2]}"
    SUBFOLDERS_FILE="${positional_args[3]}"
}

# Check prerequisites
check_prerequisites() {
    # Check if rclone is installed
    if ! command -v rclone &> /dev/null; then
        log_error "rclone is not installed or not in PATH"
        exit 1
    fi
    
    # Validate method
    case "$METHOD" in
        sync|move|copy) ;;
        *)
            log_error "Invalid method: $METHOD (must be sync, move, or copy)"
            exit 1
            ;;
    esac
    
    # Extract remote names
    local source_remote_name="$SOURCE_REMOTE"
    local dest_remote_name="$DEST_REMOTE"
    
    # Check if remotes exist
    if ! rclone listremotes | grep -q "^${source_remote_name}:$"; then
        log_error "Source remote '$source_remote_name' not found. Configure with: rclone config"
        exit 1
    fi
    
    if ! rclone listremotes | grep -q "^${dest_remote_name}:$"; then
        log_error "Destination remote '$dest_remote_name' not found. Configure with: rclone config"
        exit 1
    fi
    
    # Test remote connectivity
    log_info "Testing remote connectivity..."
    if ! rclone lsd "${SOURCE_REMOTE}:${SOURCE_BUCKET}" --max-depth 1 &> /dev/null; then
        log_error "Cannot access source: ${SOURCE_REMOTE}:${SOURCE_BUCKET}"
        exit 1
    fi
    
    local dest_bucket="${DEST_BUCKET:-$SOURCE_BUCKET}"
    if ! rclone lsd "${DEST_REMOTE}:" --max-depth 1 &> /dev/null; then
        log_error "Cannot access destination remote: ${DEST_REMOTE}:"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Build rclone command options
build_rclone_opts() {
    local opts=""
    
    # Parallel transfers
    opts="$opts --transfers $PARALLEL_TRANSFERS"
    opts="$opts --checkers $CHECKERS"
    
    # Bandwidth limit
    if [ -n "$BANDWIDTH_LIMIT" ]; then
        opts="$opts --bwlimit $BANDWIDTH_LIMIT"
    fi
    
    # Progress and logging
    opts="$opts --progress"
    opts="$opts --stats 30s"
    opts="$opts --log-level INFO"
    
    # Performance optimizations
    opts="$opts --fast-list"
    opts="$opts --multi-thread-streams 4"
    
    # Handle different storage classes
    opts="$opts --ignore-checksum"  # Skip checksum for Glacier files
    
    # Dry run
    if [ "$DRY_RUN" = true ]; then
        opts="$opts --dry-run"
    fi
    
    echo "$opts"
}

# Check if directory has available files
check_directory_availability() {
    local source_path="$1"
    
    if [ "$CHECK_FIRST" = false ]; then
        return 0
    fi
    
    # Use rclone lsf to check if directory has files
    local file_count
    file_count=$(rclone lsf "$source_path" --recursive --files-only | wc -l)
    
    if [ "$file_count" -gt 0 ]; then
        log_info "Found $file_count files in $source_path"
        return 0
    else
        log_warn "No files found in $source_path"
        return 1
    fi
}

# Build destination path with optional bucket override and structure preservation
build_dest_path() {
    local subfolder="$1"
    
    # Determine destination bucket
    local dest_bucket="${DEST_BUCKET:-$SOURCE_BUCKET}"
    
    if [ "$PRESERVE_STRUCTURE" = true ]; then
        echo "${DEST_REMOTE}:${dest_bucket}/${subfolder}"
    else
        # Flatten structure - extract just the folder name
        local folder_name
        folder_name=$(basename "$subfolder")
        echo "${DEST_REMOTE}:${dest_bucket}/${folder_name}/"
    fi
}

# Move/copy single directory
transfer_directory() {
    local subfolder="$1"
    local method="$2"
    
    # Ensure subfolder ends with / for proper directory handling
    if [[ "$subfolder" != */ ]]; then
        subfolder="${subfolder}/"
    fi
    
    # Build full source path
    local source_path="${SOURCE_REMOTE}:${SOURCE_BUCKET}/${subfolder}"
    local dest_path
    dest_path=$(build_dest_path "$subfolder")
    
    log_info "Processing directory: $source_path"
    log_info "Destination: $dest_path"
    
    # Check availability
    if ! check_directory_availability "$source_path"; then
        NOT_AVAILABLE_FILES=$((NOT_AVAILABLE_FILES + 1))
        return 0
    fi
    
    local rclone_opts=$(build_rclone_opts)
    local start_time=$(date +%s)
    
    case "$method" in
        move)
            log_info "Moving directory with rclone move..."
            if rclone move "$source_path" "$dest_path" $rclone_opts 2>> "$LOG_FILE"; then
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                SUCCESS_FILES=$((SUCCESS_FILES + 1))
                log_success "Moved directory: $subfolder (${duration}s)"
            else
                ERROR_FILES=$((ERROR_FILES + 1))
                log_error "Failed to move directory: $subfolder"
            fi
            ;;
        sync)
            log_info "Syncing directory with rclone sync..."
            # First sync to destination
            if rclone sync "$source_path" "$dest_path" $rclone_opts 2>> "$LOG_FILE"; then
                # Then delete source directory if not dry run
                if [ "$DRY_RUN" = false ]; then
                    log_info "Deleting source directory after successful sync..."
                    if rclone purge "$source_path" 2>> "$LOG_FILE"; then
                        local end_time=$(date +%s)
                        local duration=$((end_time - start_time))
                        SUCCESS_FILES=$((SUCCESS_FILES + 1))
                        log_success "Synced and deleted directory: $subfolder (${duration}s)"
                    else
                        log_warn "Synced but failed to delete source directory: $subfolder"
                        SUCCESS_FILES=$((SUCCESS_FILES + 1))
                    fi
                else
                    local end_time=$(date +%s)
                    local duration=$((end_time - start_time))
                    SUCCESS_FILES=$((SUCCESS_FILES + 1))
                    log_success "Would sync and delete directory: $subfolder (${duration}s)"
                fi
            else
                ERROR_FILES=$((ERROR_FILES + 1))
                log_error "Failed to sync directory: $subfolder"
            fi
            ;;
        copy)
            log_info "Copying directory with rclone copy..."
            if rclone copy "$source_path" "$dest_path" $rclone_opts 2>> "$LOG_FILE"; then
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                SUCCESS_FILES=$((SUCCESS_FILES + 1))
                log_success "Copied directory: $subfolder (${duration}s)"
            else
                ERROR_FILES=$((ERROR_FILES + 1))
                log_error "Failed to copy directory: $subfolder"
            fi
            ;;
    esac
    
    # Small delay between directories
    sleep 1
}

# Log progress
log_progress() {
    log_info "Progress: Folders ${PROCESSED_FOLDERS}/${TOTAL_FOLDERS} | Success: ${SUCCESS_FILES} | Errors: ${ERROR_FILES} | Not available: ${NOT_AVAILABLE_FILES}"
}

# Clean up empty directories after move
cleanup_empty_dirs() {
    if [ "$DELETE_EMPTY_DIRS" = true ] && [ "$METHOD" != "copy" ] && [ "$DRY_RUN" = false ]; then
        log_info "Cleaning up empty directories in source..."
        rclone rmdirs "${SOURCE_REMOTE}:${SOURCE_BUCKET}" --leave-root 2>> "$LOG_FILE" || true
    fi
}

# Main processing function
process_directories() {
    local subfolders_file="$1"
    
    if [ ! -f "$subfolders_file" ]; then
        log_error "Subfolders file not found: $subfolders_file"
        exit 1
    fi
    
    # Count total directories
    TOTAL_FOLDERS=$(grep -c . "$subfolders_file" 2>/dev/null || echo "0")
    log_info "Found $TOTAL_FOLDERS directories to process"
    
    local start_time=$(date +%s)
    
    # Process each directory
    while IFS= read -r subfolder || [ -n "$subfolder" ]; do
        [ -z "$subfolder" ] && continue
        
        PROCESSED_FOLDERS=$((PROCESSED_FOLDERS + 1))
        log_info "Processing directory $PROCESSED_FOLDERS/$TOTAL_FOLDERS: $subfolder"
        
        transfer_directory "$subfolder" "$METHOD"
        
        # Progress update
        log_progress
        
    done < "$subfolders_file"
    
    # Cleanup empty directories
    cleanup_empty_dirs
    
    # Final statistics
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local avg_time_per_folder=0
    if [ "$PROCESSED_FOLDERS" -gt 0 ]; then
        avg_time_per_folder=$((duration / PROCESSED_FOLDERS))
    fi
    
    echo
    log_info "=============================================="
    log_info "FINAL RESULTS:"
    log_info "Method used: $METHOD"
    log_info "Total directories processed: $PROCESSED_FOLDERS"
    log_success "Successful transfers: $SUCCESS_FILES"
    log_info "Not available (files may be in Glacier): $NOT_AVAILABLE_FILES"
    if [ "$ERROR_FILES" -gt 0 ]; then
        log_error "Errors: $ERROR_FILES"
    else
        log_success "Errors: $ERROR_FILES"
    fi
    log_info "Total processing time: ${duration}s"
    log_info "Average time per directory: ${avg_time_per_folder}s"
    log_info "Log file: $LOG_FILE"
    if [ "$PRESERVE_STRUCTURE" = false ]; then
        log_info "Directory structure was flattened"
    fi
    log_info "=============================================="
    
    return "$ERROR_FILES"
}

# Signal handler
cleanup_on_signal() {
    log_warn "Script interrupted at directory $PROCESSED_FOLDERS"
    log_progress
    exit 130
}
trap cleanup_on_signal SIGINT SIGTERM

# Main function
main() {
    parse_args "$@"
    
    # Validate required arguments
    if [ -z "$SOURCE_REMOTE" ] || [ -z "$SOURCE_BUCKET" ] || [ -z "$DEST_REMOTE" ] || [ -z "$SUBFOLDERS_FILE" ]; then
        log_error "Missing required arguments"
        usage
        exit 1
    fi
    
    check_prerequisites
    
    log_info "Starting rclone directory transfer"
    log_info "Source: ${SOURCE_REMOTE}:${SOURCE_BUCKET}"
    log_info "Destination: ${DEST_REMOTE}:${DEST_BUCKET:-$SOURCE_BUCKET}"
    if [ -n "$DEST_BUCKET" ]; then
        log_info "Destination bucket override: $DEST_BUCKET"
    fi
    log_info "Method: $METHOD"
    log_info "Subfolders file: $SUBFOLDERS_FILE"
    log_info "Preserve structure: $PRESERVE_STRUCTURE"
    if [ "$DRY_RUN" = true ]; then
        log_warn "DRY RUN MODE - No actual transfers will be performed"
    fi
    
    process_directories "$SUBFOLDERS_FILE"
    local exit_code=$?
    
    if [ "$exit_code" -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi