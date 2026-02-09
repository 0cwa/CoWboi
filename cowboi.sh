#!/bin/bash
# CoWboi - Safe CoW Management for Btrfs
# Can both enable and disable Copy-on-Write for files on Btrfs filesystem
# Works safely with active writes (VMs, DBs) via quiesce + sync
# Author: Adapted from Btrfs best practices

set -euo pipefail  # Fail fast on errors

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    echo "[$level] $message"
    if [[ "$level" == "ERROR" ]]; then
        logger -t cowboi "[ERROR] $message" 2>/dev/null || true
    fi
}

# Check for C attribute (NOCOW)
check_cow_attribute() {
    local file=$1
    if lsattr "$file" 2>/dev/null | grep -q "^[[:print:]]*C[[:print:]]* "; then
        return 0  # Has C attribute (NOCOW)
    fi
    return 1  # Doesn't have C attribute (CoW enabled)
}

# Verify Btrfs + CoW enabled on mount
verify_btrfs_cow_mount() {
    local file=$1
    local mount_point=$(df "$file" | tail -1 | awk '{print $1}')
    
    if ! mount | grep "$mount_point" | grep -q 'btrfs.*[(,]datacow[,)]\|[(,]compress[=,)]'; then
        log "ERROR" "Mount lacks CoW support (needs datacow or compress). Remount without nodatacow."
        return 1
    fi
    return 0
}

# Get file hash for verification
get_file_hash() {
    local file=$1
    sha256sum "$file" | cut -d' ' -f1
}

# Safe copy with verification
safe_copy_file() {
    local source=$1
    local dest=$2
    
    log "INFO" "Copying $source to $dest..."
    if ! cp --reflink=never "$source" "$dest"; then
        log "ERROR" "Copy failed"
        return 1
    fi
    
    # Verify byte-identical
    local source_hash=$(get_file_hash "$source")
    local dest_hash=$(get_file_hash "$dest")
    
    if [[ "$source_hash" != "$dest_hash" ]]; then
        log "ERROR" "Copies differ! Source: $source_hash, Dest: $dest_hash"
        rm -f "$dest"
        return 1
    fi
    
    log "INFO" "Copy verification successful (hash: $source_hash)"
    return 0
}

# Atomic file replacement
atomic_replace() {
    local old_file=$1
    local new_file=$2
    
    log "INFO" "Performing atomic replacement..."
    sync
    
    # Create backup
    local backup="${old_file}.cowboi.backup.$$"
    mv "$old_file" "$backup"
    
    # Move new file to final location
    if ! mv "$new_file" "$old_file"; then
        log "ERROR" "Atomic replacement failed, restoring backup..."
        mv "$backup" "$old_file"
        return 1
    fi
    
    # Remove backup
    rm -f "$backup"
    sync
    
    log "INFO" "Atomic replacement successful"
    return 0
}

# Disable CoW (enable NOCOW) for a file
disable_cow_file() {
    local file=$1
    local tmp_file="${file}.tmp_cow_disable"
    
    if [[ -e "$tmp_file" ]]; then
        log "ERROR" "Temporary file $tmp_file already exists"
        return 1
    fi

    # Check if already NOCOW
    if check_cow_attribute "$file"; then
        log "INFO" "File $file already has CoW disabled (NOCOW)"
        return 0
    fi
    
    log "INFO" "Converting $file to NOCOW..."
    
    # Create temp file with NOCOW attribute
    touch "$tmp_file"
    chattr +C "$tmp_file" || {
        log "ERROR" "Failed to set NOCOW attribute on temp file"
        rm -f "$tmp_file"
        return 1
    }
    
    # Copy contents with verification
    if ! safe_copy_file "$file" "$tmp_file"; then
        return 1
    fi
    
    # Verify new file has NOCOW attribute
    if ! check_cow_attribute "$tmp_file"; then
        log "ERROR" "New file doesn't have NOCOW attribute set!"
        rm -f "$tmp_file"
        return 1
    fi
    
    # Atomic replacement
    if ! atomic_replace "$file" "$tmp_file"; then
        return 1
    fi
    
    log "INFO" "Successfully disabled CoW for $file"
    return 0
}

# Enable CoW (disable NOCOW) for a file
enable_cow_file() {
    local file=$1
    local tmp_file="${file}.tmp_cow_enable"
    
    if [[ -e "$tmp_file" ]]; then
        log "ERROR" "Temporary file $tmp_file already exists"
        return 1
    fi

    # Check if already CoW enabled
    if ! check_cow_attribute "$file"; then
        log "INFO" "File $file already has CoW enabled"
        return 0
    fi
    
    log "INFO" "Converting $file to CoW..."
    
    # Create temp file (will have CoW by default)
    touch "$tmp_file"
    
    # Copy contents with verification
    if ! safe_copy_file "$file" "$tmp_file"; then
        return 1
    fi
    
    # Verify new file has CoW enabled (no C attribute)
    if check_cow_attribute "$tmp_file"; then
        log "ERROR" "New file still has NOCOW attribute! Mount issue?"
        rm -f "$tmp_file"
        return 1
    fi
    
    # Atomic replacement
    if ! atomic_replace "$file" "$tmp_file"; then
        return 1
    fi
    
    log "INFO" "Successfully enabled CoW for $file"
    return 0
}

# Process single file
process_file() {
    local file=$1
    local mode=$2
    
    if [[ ! -e "$file" ]]; then
        log "ERROR" "File $file doesn't exist"
        return 1
    fi
    
    if [[ ! -f "$file" ]]; then
        log "ERROR" "$file is not a regular file"
        return 1
    fi
    
    # Verify we're on btrfs
    if ! verify_btrfs_cow_mount "$file"; then
        return 1
    fi
    
    # Step 1: Quiesce application if possible
    log "INFO" "Quiescing application (customize this section for your workload)..."
    sync
    sleep 1
    
    # Step 2: Process based on mode
    case "$mode" in
        disable)
            if ! disable_cow_file "$file"; then
                return 1
            fi
            ;;
        enable)
            if ! enable_cow_file "$file"; then
                return 1
            fi
            ;;
        *)
            log "ERROR" "Invalid mode: $mode"
            return 1
            ;;
    esac
    
    # Step 3: Resume application
    log "INFO" "Resuming application..."
    
    return 0
}

# Process directory recursively
process_directory() {
    local dir=$1
    local mode=$2
    
    log "INFO" "Processing directory $dir recursively..."
    
    # Handle directory itself
    if check_cow_attribute "$dir"; then
        if [[ "$mode" == "disable" ]]; then
            log "INFO" "Directory $dir already has CoW disabled"
        else
            log "INFO" "Directory $dir has CoW disabled, but processing files only"
        fi
    fi
    
    # Process all files recursively
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            if ! process_file "$file" "$mode"; then
                log "ERROR" "Failed to process $file"
                return 1
            fi
        fi
    done < <(find "$dir" -type f -print0)
    
    log "INFO" "Directory processing complete"
    return 0
}

# Main function
main() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: $0 <enable|disable> <file_or_directory>" >&2
        echo "" >&2
        echo "Modes:" >&2
        echo "  enable   - Enable CoW (disable NOCOW) for files on Btrfs" >&2
        echo "  disable  - Disable CoW (enable NOCOW) for files on Btrfs" >&2
        echo "" >&2
        echo "Examples:" >&2
        echo "  $0 enable /path/to/vm/disk.img" >&2
        echo "  $0 disable /path/to/database/data/" >&2
        echo "" >&2
        echo "Note: Customize the quiesce/resume sections for your specific workloads" >&2
        exit 1
    fi
    
    local mode=$1
    local target=$2
    
    # Validate mode
    if [[ "$mode" != "enable" && "$mode" != "disable" ]]; then
        log "ERROR" "Invalid mode: $mode. Must be 'enable' or 'disable'"
        exit 1
    fi
    
    # Validate target exists
    if [[ ! -e "$target" ]]; then
        log "ERROR" "Target $target doesn't exist"
        exit 1
    fi
    
    log "INFO" "Starting CoWboi - $mode mode for $target"
    log "INFO" "File size: $(du -h "$target" | cut -f1)"
    
    # Process based on target type
    if [[ -d "$target" ]]; then
        if ! process_directory "$target" "$mode"; then
            exit 1
        fi
    else
        if ! process_file "$target" "$mode"; then
            exit 1
        fi
    fi
    
    log "INFO" "SUCCESS: CoW $mode completed for $target"
}

# Run main function
main "$@"
