#!/bin/bash

# Script to create symlinks from /sbbs to /data directories
# This script:
# 1. Looks through all directories in /data (volume mount)
# 2. For each directory, checks if it exists in /sbbs
# 3. If it exists in /sbbs, moves it to /sbbs-backup
# 4. Creates a symlink from /sbbs/<dir> to /data/<dir>

set -e  # Exit on error

# Define directories to ignore (add more as needed)
IGNORE_DIRS=(
    "exec"
    "install"
    "src"
    "backup"
    "docker-scripts"
)

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to log messages
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Function to check if a directory should be ignored
should_ignore() {
    local dir_name="$1"
    for ignore in "${IGNORE_DIRS[@]}"; do
        if [ "$dir_name" = "$ignore" ]; then
            return 0  # Should ignore (true)
        fi
    done
    return 1  # Should not ignore (false)
}

# Check if required directories exist
if [ ! -d "/data" ]; then
    log_error "/data directory does not exist!"
    exit 1
fi

if [ ! -d "/sbbs" ]; then
    log_error "/sbbs directory does not exist!"
    exit 1
fi

# Create backup directory if it doesn't exist
if [ ! -d "/data/backup" ]; then
    log "Creating /data/backup directory"
    mkdir -p /data/backup
fi

# PHASE 1: Initialize /data with any missing directories from /sbbs
log "Phase 1: Checking for directories to copy from /sbbs to /data..."

for sbbs_dir in /sbbs/*/; do
    # Skip if no directories found
    [ -d "$sbbs_dir" ] || continue
    
    # Get the directory name without path
    dir_name=$(basename "$sbbs_dir")
    
    # Skip ignored directories
    if should_ignore "$dir_name"; then
        log "  → Ignoring directory: $dir_name"
        continue
    fi
    
    # Skip if it's already a symlink (from a previous run)
    if [ -L "$sbbs_dir" ]; then
        continue
    fi
    
    data_path="/data/$dir_name"
    
    # Check if this directory exists in /data
    if [ ! -e "$data_path" ]; then
        log "Initializing: $dir_name"
        log "  → Copying from $sbbs_dir to $data_path"
        
        # Copy the directory to /data
        cp -a "$sbbs_dir" "$data_path"
        
        if [ -d "$data_path" ]; then
            log "  → Successfully copied!"
        else
            log_error "  → Failed to copy directory!"
            exit 1
        fi
    else
        log "  → $dir_name already exists in /data, skipping"
    fi
done

# PHASE 2: Process each directory in /data and create symlinks
log "Phase 2: Creating symlinks from /sbbs to /data..."

for data_dir in /data/*/; do
    # Skip if no directories found
    [ -d "$data_dir" ] || continue
    
    # Get the directory name without path
    dir_name=$(basename "$data_dir")
    
    # Skip ignored directories
    if should_ignore "$dir_name"; then
        log "  → Ignoring directory: $dir_name"
        continue
    fi
    
    sbbs_path="/sbbs/$dir_name"
    backup_path="/data/backup/$dir_name"
    
    log "Processing: $dir_name"
    
    # Check if the path already exists in /sbbs
    if [ -e "$sbbs_path" ]; then
        # Check if it's already a symlink pointing to the correct location
        if [ -L "$sbbs_path" ] && [ "$(readlink -f "$sbbs_path")" = "$(readlink -f "$data_dir")" ]; then
            log "  → Symlink already exists and is correct, skipping"
            continue
        fi
        
	# If backup already exists, append timestamp
        # if [ -e "$backup_path" ]; then
        #     timestamp=$(date +%Y%m%d_%H%M%S)
        #     backup_path="${backup_path}_${timestamp}"
        #     log_warn "  → Backup already exists, using: $backup_path"
        # fi
        
        # It exists but isn't a correct symlink, so we need to back it up
        log "  → Found existing item at $sbbs_path"
        
        if [ -e "$backup_path" ]; then
            log "  → Backup already exists, deleting $sbbs_path"
	    rm -rf "$sbbs_path"
        else
            # Move to backup
            log "  → Moving to backup: $backup_path"
            mv "$sbbs_path" "$backup_path"
	fi
    fi
    
    # Create the symlink
    log "  → Creating symlink: $sbbs_path -> $data_dir"
    ln -s "$data_dir" "$sbbs_path"
    
    # Verify the symlink was created successfully
    if [ -L "$sbbs_path" ]; then
        log "  → Success!"
    else
        log_error "  → Failed to create symlink!"
        exit 1
    fi
done

log "Symlink setup completed successfully!"

# Optional: List all created symlinks for verification
log "Current symlinks in /sbbs:"
find /sbbs -type l -ls | while read line; do
    echo "  $line"
done
