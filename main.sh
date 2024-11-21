#!/bin/bash


SCRIPT_DIR=$(dirname "$(realpath "$0")")
ARTIFACTS_DIR="$SCRIPT_DIR/artifacts"
EXCLUDE_CONF="$SCRIPT_DIR/rclone_exclude.txt"
BACKUP_CONF="$SCRIPT_DIR/script_conf.txt"
TARGET_BUCKET="b2:ken-dell-backup"
LOG_FILE="$ARTIFACTS_DIR/log_$(date +%Y%m%d).log"



# Log start time and message
echo "Starting backup process at $(date)" | tee -a "$LOG_FILE"

# Step 1: Change to the /home/ken/dev/backups directory
cd "$SCRIPT_DIR" || { echo "Failed to change directory"; exit 1; }
# cd "$SCRIPT_DIR" || { echo "Failed to change directory"; exit 1; }

# Log the directory change
echo "Changed to \"$SCRIPT_DIR\"" | tee -a "$LOG_FILE"

# Step 2: Run the backup script
echo "Running backup script..." | tee -a "$LOG_FILE"
./backup_script.sh -l -pf "$BACKUP_CONF" -n 2>&1 | tee -a "$LOG_FILE"

# Log the completion of the backup script
if [[ $? -eq 0 ]]; then
    echo "Backup script completed successfully" | tee -a "$LOG_FILE"
else
    echo "Backup script failed" | tee -a "$LOG_FILE"
    exit 1
fi

# Step 3: Sync the backup with rclone to Backblaze B2
echo "Starting rclone sync..." | tee -a "$LOG_FILE"
sudo -u ken rclone sync "$ARTIFACTS_DIR" "$TARGET_BUCKET" --exclude-from "$EXCLUDE_CONF" --progress  | tee -a "$LOG_FILE" 2>&1

# Log the completion of the rclone sync
if [[ $? -eq 0 ]]; then
    echo "rclone sync completed successfully" | tee -a "$LOG_FILE"
else
    echo "rclone sync failed" | tee -a "$LOG_FILE"
    exit 1
fi

# Final log message
echo "Backup process completed at $(date)" | tee -a "$LOG_FILE"
