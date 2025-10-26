#!/bin/bash

#################################################
# Linux Recycle Bin Simulation
# Author: [Your Name]
# Date: [Date]
# Description: Shell-based recycle bin system
#################################################

# Global Configuration
RECYCLE_BIN_DIR="$HOME/.recycle_bin"
FILES_DIR="$RECYCLE_BIN_DIR/files"
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"
CONFIG_FILE="$RECYCLE_BIN_DIR/config"

# Color codes for output (optional)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

METADATA_DELIMITER='|'
METADATA_HEADER_FIELDS="ID ORIGINAL_NAME ORIGINAL_PATH DELETION_DATE FILE_SIZE FILE_TYPE PERMISSIONS OWNER"

#################################################
# Function: initialize_recyclebin
# Description: Creates recycle bin directory structure
# Parameters: None
# Returns: 0 on success, 1 on failure
#################################################
initialize_recyclebin() {
    mkdir -p "$RECYCLE_BIN_DIR"
    chmod u+rwx "$RECYCLE_BIN_DIR"
    [[ ! -d "$FILES_DIR" ]] && mkdir -p "$FILES_DIR"
    [[ ! -f "$METADATA_FILE" ]] && {
        touch "$METADATA_FILE"
        echo "# Recycle Bin Metadata" > "$METADATA_FILE"
        echo $(join_by $METADATA_DELIMITER $METADATA_HEADER_FIELDS) >> "$METADATA_FILE"
    }
    #[[ ! -f "$CONFIG_FILE" ]] && {
    #    echo "MAX_SIZE=104857600" > "$CONFIG_FILE"  # 100 MB default
    #    echo "AUTO_EMPTY_DAYS=30" >> "$CONFIG_FILE" # 30 days default
    #}
    return 0
}

#################################################
# Function: generate_unique_id
# Description: Generates unique ID for deleted files
# Parameters: None
# Returns: Prints unique ID to stdout
#################################################
generate_unique_id() {
    local timestamp=$(date +%s)
    local random=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
    echo "${timestamp}_${random}"
}

#################################################
# Function: delete_file
# Description: Moves file/directory to recycle bin
# Parameters: $1 - path to file/directory
# Returns: 0 on success
#################################################
delete_file() {
    # Validate input
    if (($# < 1)); then
        echo -e "${RED}Error: No file(s) specified${NC}"
        return 1
    fi
    local num_files_deleted=0
    local total_files=$#
    for file in "$@"; do
        # Check if file exists
        if [ ! -e "$file" ]; then
            echo -e "${RED}Error: File '$file' does not exist${NC}"
            continue
        fi
        if [[ "$file" == "$RECYCLE_BIN_DIR"* ]]; then
            echo -e "${YELLOW}Warning: Cannot delete files from recycle bin itself: '$file'${NC}"
            continue
        fi
        # TODO: check permissions to delete
        # TODO: check filesize against config MAX_SIZE
        local metadata=$(get_metadata "$file")
        local id=$(echo "$metadata" | cut -d$METADATA_DELIMITER -f1)
        move_to_recycle_bin "$file" "$id" || continue
        update_metadata "$metadata" || continue
        num_files_deleted=$((num_files_deleted + 1))

    done
    echo -e "${GREEN}$num_files_deleted/$total_files file(s) moved to recycle bin successfully.${NC}"
}

#################################################
# Function: list_recycled
# Description: Lists all items in recycle bin
# Parameters: None
# Returns: 0 on success
#################################################
list_recycled() {
    if (( $(wc -l < "$METADATA_FILE") <= 2 )); then
        echo "Recycle bin is empty"
        return 0
    fi

    echo "=== Recycle Bin Contents ==="

    # Your code here

    printf "%-20s %-40s %-20s %-10s\n" "ID" "ORIGINAL NAME" "DELETION DATE" "SIZE"
    printf "%s\n" "--------------------------------------------------------------------------------"
    
    tail -n +3 "$METADATA_FILE" | while IFS="$METADATA_DELIMITER" read -r ID ORIGINAL_NAME ORIGINAL_PATH DELETION_DATE FILE_SIZE FILE_TYPE PERMISSIONS OWNER; do
        printf "%-20s %-40s %-20s %-10s\n" "$ID" "$ORIGINAL_NAME" "$DELETION_DATE" "$FILE_SIZE"
    done
    return 0
}

#################################################
# Function: restore_file
# Description: Restores file from recycle bin
# Parameters: $1 - unique ID of file to restore
# Returns: 0 on success, 1 on failure
#################################################
restore_file() {
    # TODO: Implement this function
    local file_id="$1"

    if [ -z "$file_id" ]; then
        echo -e "${RED}Error: No file ID specified${NC}"
        return 1
    fi
    return 1
    # Your code here

    # Hint: Search metadata for matching ID
    # Hint: Get original path from metadata
    # Hint: Check if original path exists
    # Hint: Move file back and restore permissions
    # Hint: Remove entry from metadata

    return 0
}

#################################################
# Function: empty_recyclebin
# Description: Permanently deletes all items
# Parameters: None
# Returns: 0 on success
#################################################
empty_recyclebin() {
    # TODO: Implement this function

    # Your code here

    return 1
}


#################################################
# Function: search_recycled
# Description: Searches for files in recycle bin
# Parameters: $1 - search pattern
# Returns: 0 on success
#################################################
search_recycled() {
    # TODO: Implement this function
    local pattern="$1"

    # Your code here
    # Hint: Use grep to search metadata

    return 0
}

#################################################
# Function: display_help
# Description: Shows usage information
# Parameters: None
# Returns: 0
#################################################
display_help() {
    cat << EOF
Linux Recycle Bin - Usage Guide

SYNOPSIS:
    $0 [OPTION] [ARGUMENTS]

OPTIONS:
    delete <file>       Move file/directory to recycle bin
    list                List all items in recycle bin
    restore <id>        Restore file by ID
    search <pattern>    Search for files by name
    empty               Empty recycle bin permanently
    help                Display this help message

EXAMPLES:
    $0 delete myfile.txt
    $0 list
    $0 restore 1696234567_abc123
    $0 search "*.pdf"
    $0 empty

EOF
    return 0
}

#################################################
# Function: main
# Description: Main program logic
# Parameters: Command line arguments
# Returns: Exit code
#################################################
main() {
    # Initialize recycle bin
    initialize_recyclebin

    # Parse command line arguments
    case "$1" in
        delete)
            shift
            delete_file "$@"
            ;;
        list)
            list_recycled
            ;;
        restore)
            restore_file "$2"
            ;;
        search)
            search_recycled "$2"
            ;;
        empty)
            empty_recyclebin
            ;;
        help|--help|-h)
            display_help
            ;;
        *)
            echo "Invalid option. Use 'help' for usage information."
            exit 1
            ;;
    esac
}

#################################################
# Function: reset_metadata
# Description: (Helper) Resets metadata.db file
# Parameters: None
# Returns: 0 on success
#################################################
# reset_metadata() {
#     touch "$METADATA_FILE"
#     echo "# Recycle Bin Metadata" > "$METADATA_FILE"
#     echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" >> "$METADATA_FILE"
#     return 0
# }

#################################################
# Function: get_metadata
# Description: (Helper) Generate metadata for a file or directory
# Parameters: $1 - path to file
# Returns: 0 on success
#################################################
get_metadata() {
    local file="$1"
    local ID ORIGINAL_NAME ORIGINAL_PATH DELETION_DATE FILE_SIZE FILE_TYPE PERMISSIONS OWNER

    ID=$(generate_unique_id)
    ORIGINAL_NAME=$(basename "$file")
    ORIGINAL_PATH=$(realpath "$file")
    DELETION_DATE=$(date "+%Y-%m-%d %H:%M:%S")
    FILE_SIZE=$(stat -c %s "$file")
    [ -d "$file" ] && FILE_SIZE=$(du -sb "$file" | cut -f1)
    FILE_TYPE="f"
    [ -d "$file" ] && FILE_TYPE="d"
    PERMISSIONS=$(stat -c "%a" "$file")
    OWNER=$(stat -c %U:%G "$file")

    echo $(join_by "$METADATA_DELIMITER" "$ID" "$ORIGINAL_NAME" "$ORIGINAL_PATH" "$DELETION_DATE" "$FILE_SIZE" "$FILE_TYPE" "$PERMISSIONS" "$OWNER")
    return 0
}

#################################################
# Function: move_to_recycle_bin
# Description: (Helper) Move file to recycle bin
# Parameters: $1 - path to file; $2 - unique ID
# Returns: 0 on success, 1 on failure
#################################################
move_to_recycle_bin() {
    local file="$1"
    local id="$2"

    echo "Delete function called with: $file"
    mv "$file" "$FILES_DIR/$id" || {
        echo -e "${RED}Error: Failed to move '$file' to recycle bin${NC}"
        return 1
    }
    return 0
}

#################################################
# Function: update_metadata
# Description: (Helper) Update metadata file
# Parameters: $1 - path to file
# Returns: 0 on success, 1 on failure
#################################################
update_metadata() {
    local metadata="$1"

    echo "$metadata" >> "$METADATA_FILE" || {
        echo -e "${RED}Error: Failed to update metadata${NC}"
        return 1
    }
    return 0
}

#################################################
# Function: join_by
# Description: (Helper) Joins strings by a delimiter
# Parameters: $1 - delimiter; $2... - strings to join
# Returns: Prints joined string to stdout
#################################################
join_by() {
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  fi
}
# Reference: https://stackoverflow.com/questions/1527049/how-can-i-join-elements-of-a-bash-array-into-a-delimited-string#17841619

# Execute main function with all arguments
main "$@"