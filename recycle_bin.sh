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
LOG_FILE="$RECYCLE_BIN_DIR/recyclebin.log"

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
# Returns: 0 on success
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
    [[ ! -f "$CONFIG_FILE" ]] && {
        echo "MAX_SIZE=104857600" > "$CONFIG_FILE"  # 100 MB default
        echo "AUTO_EMPTY_DAYS=30" >> "$CONFIG_FILE" # 30 days default
    }
    [[ ! -f "$LOG_FILE" ]] && touch "$LOG_FILE"
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
# Returns: 0 on success, 1 on failure
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
        # Prevent deleting from recycle bin itself
        if [[ "$file" == "$RECYCLE_BIN_DIR"* ]]; then
            echo -e "${YELLOW}Warning: Cannot delete files from recycle bin itself: '$file'${NC}"
            continue
        fi
        # Get metadata
        local metadata=$(get_metadata "$file")
        IFS="$METADATA_DELIMITER" read -r ID ORIGINAL_NAME ORIGINAL_PATH DELETION_DATE FILE_SIZE FILE_TYPE PERMISSIONS OWNER <<< "$metadata"
        # Check permissions
        local parent_dir=$(dirname "${ORIGINAL_PATH%/}")
        [ ! -w "$parent_dir" ] || [ ! -x "$parent_dir" ] && {
            echo -e "${RED}Error: No permissions in parent directory '$parent_dir'${NC}"
            continue
        }
        # Check recycle bin size limit
        (( $(get_current_size + FILE_SIZE) > $(get_config "MAX_SIZE") )) && {
            echo -e "${RED}Error: Recycle bin cannot receive '$file', otherwise it would exceed maximum allowed size${NC}"
            continue
        }
        move_to_recycle_bin "$file" "$ID" || continue
        update_metadata "$metadata" || continue
        num_files_deleted=$((num_files_deleted + 1))

    done
    if ((num_files_deleted == 0)); then
        echo -e "${RED}No files were moved to recycle bin.${NC}"
        return 1
    fi
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
        printf "%s\n" "-------------------------------------------------------------------------------------------------------------------------------"
    if [ "$1" == "--detailed" ]; then
        tail -n +3 "$METADATA_FILE" | while IFS="$METADATA_DELIMITER" read -r ID ORIGINAL_NAME ORIGINAL_PATH DELETION_DATE FILE_SIZE FILE_TYPE PERMISSIONS OWNER; do
            echo "ID: $ID"
            echo "ORIGINAL_NAME: $ORIGINAL_NAME"
            echo "ORIGINAL_PATH: ORIGINAL_PATH"
            echo "DELETION_DATE: $DELETION_DATE"
            echo "FILE_SIZE: $(human_readable_size "$FILE_SIZE")"
            echo "FILE_TYPE: $FILE_TYPE"
            echo "PERMISSIONS: $PERMISSIONS"
            echo "OWNER: $OWNER"
            echo ""
        done
    else
        printf "%-20s %-40s %-20s %-10s\n" "ID" "ORIGINAL NAME" "DELETION DATE" "SIZE"
        tail -n +3 "$METADATA_FILE" | while IFS="$METADATA_DELIMITER" read -r ID ORIGINAL_NAME ORIGINAL_PATH DELETION_DATE FILE_SIZE FILE_TYPE PERMISSIONS OWNER; do
            printf "%-20s %-40s %-20s %-10s\n" "$ID" "$ORIGINAL_NAME" "$DELETION_DATE" "$(human_readable_size "$FILE_SIZE")"
        done
    fi
    printf "%s\n" "--------------------------------------------------------------------------------"
    echo "Total items: $(( $(wc -l < "$METADATA_FILE") - 2 ))"
    echo "Storage used: $(human_readable_size $(get_current_size))/$(human_readable_size $(get_config "MAX_SIZE"))"
    return 0
}

#################################################
# Function: restore_file
# Description: Restores file from recycle bin
# Parameters: $1 - unique ID of file to restore
# Returns: 0 on success, 1 on failure
#################################################
restore_file() {
    local file_id="$1"
    echo "Restore function called with ID: $file_id"
    [ -z "$file_id" ] && {
        echo -e "${RED}Error: No file ID specified${NC}"
        return 1
    }
    
    # Search metadata for matching ID
    local metadata_line=$(cat "$METADATA_FILE" | grep "$file_id") 
    echo "$metadata_line"
    [ -z "$metadata_line" ] && {
        echo -e "${RED}Error: No file with ID '$file_id' found in recycle bin${NC}"
        return 1
    }
    # Get original path from metadata
    IFS="$METADATA_DELIMITER" read -r ID ORIGINAL_NAME ORIGINAL_PATH DELETION_DATE FILE_SIZE FILE_TYPE PERMISSIONS OWNER <<< "$metadata_line"
    [ -z "$ORIGINAL_PATH" ] && {
        echo -e "${RED}Error: Couldn't get metadata of file with ID '$file_id'${NC}"
        return 1
    }
    # Check if original path exists
    dir_path=$(dirname "$ORIGINAL_PATH")
    [ ! -d "$dir_path" ] && {
        mkdir -p "$dir_path"
    }
    chmod u+rwx "$dir_path"
    # Move file back to original path
    [ -e "$ORIGINAL_PATH" ] && {
        echo -e "${YELLOW}Warning: Original path '$ORIGINAL_PATH' already exists.${NC}"
        echo -n "Do you want to overwrite?"
        confirm_action && {
            echo "Restore cancelled."
            return 1
        }
    }
    mv "$FILES_DIR/$file_id" "$ORIGINAL_PATH" || {
        echo -e "${RED}Error: Failed to restore file to '$ORIGINAL_PATH'${NC}"
        return 1
    }
    # Restore original permissions
    chmod "$PERMISSIONS" "$ORIGINAL_PATH"
    # Remove entry from metadata
    grep -v "^$file_id$" "$METADATA_FILE" > "$METADATA_FILE.temp"
    mv "$METADATA_FILE.temp" "$METADATA_FILE"
    [ $(grep -c "^$file_id$" "$METADATA_FILE") -ne 0 ] && {
        echo -e "${RED}Error: Failed to update metadata after restoring file${NC}"
        return 1
    }
    echo -e "${GREEN}File restored to '$ORIGINAL_PATH' successfully.${NC}"
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
    delete <file> <...files>    Move file/directory to recycle bin
    list                        List all items in recycle bin
    restore <id>                Restore file by ID
    search <pattern>            Search for files by name
    empty                       Empty recycle bin permanently
    help|-h|--help              Display this help message

EXAMPLES:
    $0 delete myfile.txt anotherfile.txt
    $0 list
    $0 restore 1696234567_abc123
    $0 search "*.pdf"
    $0 empty
    $0 -h

CONFIGURATION:
    Configuration file is located at: $CONFIG_FILE
    You can edit MAX_SIZE and AUTO_EMPTY_DAYS parameters there.

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
            list_recycled "$2"
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
    [ -d "$file" ] && FILE_SIZE=$(du -sb "$file" | awk '{print $1}') || 
    FILE_TYPE="f"
    [ -d "$file" ] && FILE_TYPE="d"
    PERMISSIONS=$(stat -c "%a" "$file")
    OWNER=$(stat -c %U:%G "$file")

    # TODO: Use arrays
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


#################################################
# Function: confirm_action
# Description: (Helper) Prompts user for confirmation
# Parameters: None
# Returns: 0 if confirmed, 1 otherwise
#################################################
confirm_action() { 
    read -p " (y/n): " choice 
    case "$choice" in 
        y|Y|yes|YES) return 0 ;; 
        *) return 1 ;; 
    esac 
}

#################################################
# Function: get_current_size
# Description: (Helper) Get current size of recycle bin
# Parameters: None
# Returns: Prints size in bytes to stdout
#################################################
get_current_size() {
    local total_size=0
    while read -r line; do
        IFS="$METADATA_DELIMITER" read -r ID ORIGINAL_NAME ORIGINAL_PATH DELETION_DATE FILE_SIZE FILE_TYPE PERMISSIONS OWNER <<< "$line"
        total_size=$((total_size + FILE_SIZE))
    done < <(tail -n +3 "$METADATA_FILE")
    echo "$total_size"
}

#################################################
# Function: get_config
# Description: (Helper) Get configuration value
# Parameters: $1 - config key
# Returns: Prints config value to stdout
#################################################
get_config() {
    local key="$1"
    echo $(grep "^$key=" "$CONFIG_FILE" | cut -d'=' -f2)
}

#################################################
# Function: human_readable_size
# Description: (Helper) Convert bytes to human-readable format
# Parameters: $1 - size in bytes
# Returns: Prints human-readable size to stdout
#################################################
human_readable_size() {
    local size=$1
    if [ "$size" -lt 1024 ]; then
        printf "%3d B " "$size"
    elif [ "$size" -lt $((1024**2)) ]; then
        printf "%3d KB" $((size / 1024))
    elif [ "$size" -lt $((1024**3)) ]; then
        printf "%3d MB" $((size / 1024**2))
    else
        printf "%3d GB" $((size / 1024**3))
    fi
}

# Execute main function with all arguments
main "$@"