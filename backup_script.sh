#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 [-f | -l] [-p PATH] [-o OUTPUT] [--path-from FILE|-pf FILE] [--no-timestamp|-n]"
    echo "  -f, --full           Perform a full backup (includes everything)"
    echo "  -l, --lightweight    Perform a lightweight backup (excludes Python venvs and node_modules)"
    echo "  -p, --path PATH      Specify a directory to back up"
    echo "  -pf, --path-from FILE  Specify a file containing a list of directories to back up"
    echo "  -o, --output FILE    Specify the output tarball file name"
    echo "  -n, --no-timestamp   Omit timestamp from the backup filename"
    exit 1
}

grab_dirname() {
    ABSPATH=$1
    LAST_DIR=$(echo "$ABSPATH" | awk -F/ '{print $NF}')

    echo $LAST_DIR  # Output: somefolder

}


# Parse command-line arguments
BACKUP_TYPE="full"  # Default backup type is full
SOURCE_DIR=""
BACKUP_FILE=""
WORKDIR=$(pwd)
NO_TIMESTAMP=0  # Flag to control timestamp appending
PATH_FILE=""

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
        -pf|--path-from)
            PATH_FILE="$2"
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

# Validate if either SOURCE_DIR or PATH_FILE is provided
if [[ -z "$SOURCE_DIR" && -z "$PATH_FILE" ]]; then
    echo "Error: You must specify a directory to back up using -p or --path, or provide a file with directories using -pf."
    exit 1
fi

# Function to perform backup for a given directory
perform_backup() {
    local dir=$1
    echo "Backing up directory: $dir"

    if [[ "$BACKUP_FILE" -eq 0 ]]; then
        BACKUP_FILE=$(grab_dirname "$dir")
    fi
    
    # Validate if the directory exists
    if [[ ! -d "$dir" ]]; then
        echo "Error: Directory '$dir' does not exist."
        return 1
    fi

    # Initialize an array to store exclusions
    EXCLUDES=()

    # If it's a lightweight backup, exclude virtual environments and node_modules
    if [[ "$BACKUP_TYPE" == "lightweight" ]]; then
        echo "Excluding Python virtual environments and node_modules directories..."

        # Exclude virtual environment directories (containing pyvenv.cfg)
        while IFS= read -r venv; do
            REL_VENV_PATH="${venv#$dir/}"
            EXCLUDES+=("--exclude=$REL_VENV_PATH")
        done < <(find "$dir" -type f -name "pyvenv.cfg" -exec dirname {} \;)

        # Exclude node_modules directories
        while IFS= read -r node_modules; do
            REL_NODE_MODULES_PATH="${node_modules#$dir/}"
            EXCLUDES+=("--exclude=$REL_NODE_MODULES_PATH")
        done < <(find "$dir" -type d -name "node_modules")
    fi

    # Change directory to the source directory's parent to avoid absolute paths
    cd "$dir" || exit

    # Create the backup output directory if it doesn't exist
    BACKUP_DIR="$WORKDIR/artifacts/$BACKUP_FILE"
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
    echo "tar ${EXCLUDES[*]} -cvpzf \"$BACKUP_DIR/$BACKUP_FILE_NAME\" ."

    # Execute the tar command with exclusions
    tar "${EXCLUDES[@]}" -cvpzf "$BACKUP_DIR/$BACKUP_FILE_NAME" .

    # Notify the user of completion
    if [[ $? -eq 0 ]]; then
        echo "Backup completed successfully. File: $BACKUP_DIR/$BACKUP_FILE_NAME"
    else
        echo "Backup failed."
    fi
}

# If a path file is provided, read the file and loop through each path
if [[ -n "$PATH_FILE" ]]; then
    if [[ ! -f "$PATH_FILE" ]]; then
        echo "Error: File '$PATH_FILE' does not exist."
        exit 1
    fi

    # Loop over each line in the file and perform the backup for each path
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            perform_backup "$line"
        fi
    done < "$PATH_FILE"

# If a single path is provided, perform backup for that directory
elif [[ -n "$SOURCE_DIR" ]]; then
    perform_backup "$SOURCE_DIR"
fi
