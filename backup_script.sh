#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 [-f | -l] [-p PATH] [-o OUTPUT] [--no-timestamp|-n]"
    echo "  -f, --full           Perform a full backup (includes everything)"
    echo "  -l, --lightweight    Perform a lightweight backup (excludes Python venvs and node_modules)"
    echo "  -p, --path PATH      Specify the directory to back up"
    echo "  -o, --output FILE    Specify the output tarball file name"
    echo "  -n, --no-timestamp   Omit timestamp from the backup filename"
    exit 1
}

# Parse command-line arguments
BACKUP_TYPE="full"  # Default backup type is full
SOURCE_DIR=""
BACKUP_FILE="backup.tar.gz"
WORKDIR=$(pwd)
NO_TIMESTAMP=0  # Flag to control timestamp appending

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--full)
            BACKUP_TYPE="full"
            shift
            ;;
        -l|--lightweight)
            BACKUP_TYPE="lightweight"
            shift
            ;;
        -p|--path)
            SOURCE_DIR="$2"
            shift 2
            ;;
        -o|--output)
            BACKUP_FILE="$2"
            shift 2
            ;;
        -n|--no-timestamp)
            NO_TIMESTAMP=1
            shift
            ;;
        *)
            echo "Invalid option: $1"
            usage
            ;;
    esac
done

# Validate if SOURCE_DIR is provided
if [[ -z "$SOURCE_DIR" ]]; then
    echo "Error: You must specify a directory to back up using -p or --path."
    exit 1
fi

# Validate if the directory exists
if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Error: Directory '$SOURCE_DIR' does not exist."
    exit 1
fi

# Initialize an array to store exclusions
EXCLUDES=()

# If it's a lightweight backup, exclude virtual environments and node_modules
if [[ "$BACKUP_TYPE" == "lightweight" ]]; then
    echo "Excluding Python virtual environments and node_modules directories..."

    # Exclude virtual environment directories (containing pyvenv.cfg)
    while IFS= read -r venv; do
        REL_VENV_PATH="${venv#$SOURCE_DIR/}"
        EXCLUDES+=("--exclude=$REL_VENV_PATH")
    done < <(find "$SOURCE_DIR" -type f -name "pyvenv.cfg" -exec dirname {} \;)

    # Exclude node_modules directories
    while IFS= read -r node_modules; do
        REL_NODE_MODULES_PATH="${node_modules#$SOURCE_DIR/}"
        EXCLUDES+=("--exclude=$REL_NODE_MODULES_PATH")
    done < <(find "$SOURCE_DIR" -type d -name "node_modules")
fi

# Change directory to the source directory's parent to avoid absolute paths
cd "$SOURCE_DIR" || exit

# Create the backup output directory if it doesn't exist
BACKUP_DIR="$WORKDIR/$BACKUP_FILE"
mkdir -p "$BACKUP_DIR"  # Make the directory if it doesn't exist

# Append date to the backup filename, unless --no-timestamp flag is set
if [[ "$NO_TIMESTAMP" -eq 0 ]]; then
    DATE_SUFFIX=$(date +%Y%m%d)
    BACKUP_FILE_NAME="${BACKUP_FILE}-${DATE_SUFFIX}.tar.gz"
else
    BACKUP_FILE_NAME="${BACKUP_FILE}.tar.gz"
fi

# Print the constructed tar command for verification
echo "The following tar command will be executed:"
echo "sudo tar ${EXCLUDES[*]} -cvpzf \"$BACKUP_DIR/$BACKUP_FILE_NAME\" ."

# Execute the tar command with exclusions
sudo tar "${EXCLUDES[@]}" -cvpzf "$BACKUP_DIR/$BACKUP_FILE_NAME" .

# Notify the user of completion
if [[ $? -eq 0 ]]; then
    echo "Backup completed successfully. File: $BACKUP_DIR/$BACKUP_FILE_NAME"
else
    echo "Backup failed."
fi
