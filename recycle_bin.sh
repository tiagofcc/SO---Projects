#!/bin/bash

#################################################
# Linux Recycle Bin Simulation
# Author: João Pedro Silva -120610
# Author: Tiago Francisco Costa - 125943
# Date: [Date]
# Description: Shell-based recycle bin system
#################################################

# Global Configuration
RECYCLE_BIN_DIR="$HOME/.recycle_bin"
FILES_DIR="$RECYCLE_BIN_DIR/files"
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"
CONFIG_FILE="$RECYCLE_BIN_DIR/config"
LOG_FILE="$RECYCLE_BIN_DIR/recyclebin.log"
SCRIPT="$0"
# TODO: review function parameters and return values

# Color codes for output (optional)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

METADATA_DELIMITER=''
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
    [[ ! -f "$CONFIG_FILE" ]] && {
        echo "MAX_SIZE=104857600" > "$CONFIG_FILE"  # 100 MB default
        echo "RETENTION_DAYS=30" >> "$CONFIG_FILE" # 30 days default
        echo "AUTO_CLEANUP_STATUS=ON" >> "$CONFIG_FILE"
        echo "METADATA_DELIMITER=|" >> "$CONFIG_FILE"
    }
    METADATA_DELIMITER=$(get_config "METADATA_DELIMITER")
    [[ ! -f "$METADATA_FILE" ]] && {
        echo "# Recycle Bin Metadata" > "$METADATA_FILE"
        echo $(join_by $METADATA_DELIMITER $METADATA_HEADER_FIELDS) >> "$METADATA_FILE"
    }

    [[ ! -f "$LOG_FILE" ]] && get_log "initialize_recyclebin - Recycle Bin initialized."
    [[ $(get_config "AUTO_CLEANUP_STATUS") == "ON" ]] && auto_cleanup
    return 0
}

#################################################
# Function: auto_cleanup
# Description: Automatically deletes files older than RETENTION_DAYS
# Parameters: None
# Returns: 0 on success
#################################################
auto_cleanup() {
    local retention_days=$(get_config "RETENTION_DAYS")
    local cutoff_date=$(date --date="$retention_days days ago" "+%Y-%m-%d %H:%M:%S")
    local temp_metadata="$METADATA_FILE.temp"
    local cleaned_files=0
    echo "# Recycle Bin Metadata" > "$temp_metadata"
    echo $(join_by $METADATA_DELIMITER $METADATA_HEADER_FIELDS) >> "$temp_metadata"

    tail -n +3 "$METADATA_FILE" | while IFS="$METADATA_DELIMITER" read -r id original_name original_path deletion_date file_size file_type permissions owner; do
        if [[ "$deletion_date" < "$cutoff_date" ]]; then
            rm -rf "$FILES_DIR/$id"
            echo "$(date "+%Y-%m-%d %H:%M:%S") - Auto-deleted: $ORIGINAL_NAME (ID: $id)" >> "$LOG_FILE"
            cleaned_files=$((cleaned_files + 1))
            get_log "auto_cleanup - File with ID: $file_id auto-cleaned from recycle bin."
        else
            echo $(join_by "$METADATA_DELIMITER" "$id" "$ORIGINAL_NAME" "$ORIGINAL_PATH" "$deletion_date" "$FILE_SIZE" "$FILE_TYPE" "$PERMISSIONS" "$OWNER") >> "$temp_metadata"
        fi
    done

    get_log "auto_cleanup - Auto-cleanup completed. Files deleted: $cleaned_files."
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
# Parameters: $@ - paths to file/directory
# Returns: 0 on success, 1 when no files deleted
#################################################
delete_file() {
    # Validate input
    echo "Delete function called with arguments: $@"
    if (($# == 0)); then
        echo -e "${RED}Error: No file(s) specified${NC}"
        return 1
    fi
    local num_files_deleted=0
    local total_files=$#
    for file in "$@"; do
        # Check if file exists
        [ ! -e "$file" ] && {
            echo -e "${RED}Error: File '$file' does not exist${NC}"
            continue
        }
        # Prevent deleting from recycle bin itself
        if [[ "$(realpath "$file")" == "$(realpath "$RECYCLE_BIN_DIR")"* ]]; then
            echo -e "${YELLOW}Warning: Cannot delete files from recycle bin itself: '$file'${NC}"
            continue
        fi
        # Prevent deleting script itself
        if [ "$(realpath "$file")" == "$(realpath "$SCRIPT")" ]; then
            echo -e "${YELLOW}Warning: Cannot delete the recycle bin script itself: '$file'${NC}"
            continue
        fi
        # Get metadata
        local metadata=$(get_metadata "$file")
        IFS="$METADATA_DELIMITER" read -r id original_name original_path deletion_date file_size file_type permissions owner <<< "$metadata"
        # Check permissions for parent directory
        local parent_dir=$(dirname "${original_path%/}")
        [ ! -w "$parent_dir" ] || [ ! -x "$parent_dir" ] && {
            echo -e "${RED}Error: No permissions in parent directory '$parent_dir'${NC}"
            continue
        }
        # Check file read/write permissions
        [ ! -r "$original_path" ] || [ ! -w "$original_path" ] && {
            echo -e "${RED}Error: No read/write permissions for '$original_path'${NC}"
            continue
        }
        # Check recycle bin size limit
        (( $(get_current_size + file_size) > $(get_config "MAX_SIZE") )) && {
            echo -e "${RED}Error: Recycle bin cannot receive '$file', otherwise it would exceed maximum allowed size${NC}"
            continue
        }
        move_to_recycle_bin "$file" "$id" || continue
        update_metadata "$metadata" || continue
        num_files_deleted=$((num_files_deleted + 1))

        get_log "deleted_file - $original_name moved to recycle bin with ID: $id."


    done
    if ((num_files_deleted == 0)); then
        echo -e "${RED}No files were moved to recycle bin.${NC}"
        return 1
    fi
    echo -e "${GREEN}$num_files_deleted/$total_files file(s) moved to recycle bin successfully.${NC}"
    return 0
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

    local id original_name original_path deletion_date file_size file_type permissions owner;
    echo "=== Recycle Bin Contents ==="
        printf "%s\n" "--------------------------------------------------------------------------------"
    if [ "$1" == "--detailed" ]; then
        tail -n +3 "$METADATA_FILE" | while IFS="$METADATA_DELIMITER" read -r id original_name original_path deletion_date file_size file_type permissions owner; do
            echo "ID: $id"
            echo "ORIGINAL_NAME: $original_name"
            echo "ORIGINAL_PATH: $original_path"
            echo "DELETION_DATE: $deletion_date"
            echo "FILE_SIZE: $(human_readable_size "$file_size")"
            echo "FILE_TYPE: $file_type"
            echo "PERMISSIONS: $permissions"
            echo "OWNER: $owner"
            echo ""
        done
    else
        printf "%-20s %-30s %-20s %-10s\n" "ID" "ORIGINAL NAME" "DELETION DATE" "SIZE"
        tail -n +3 "$METADATA_FILE" | while IFS="$METADATA_DELIMITER" read -r id original_name original_path deletion_date file_size file_type permissions owner; do
            [ "$original_name" == "${original_name:0:25}" ] || original_name="${original_name:0:22}..."
            printf "%-20s %-30s %-20s %-10s\n" "$id" "$original_name" "$deletion_date" "$(human_readable_size "$file_size")"
        done
    fi
    printf "%s\n" "--------------------------------------------------------------------------------"
    echo "Total items: $(( $(wc -l < "$METADATA_FILE") - 2 ))"
    echo "Storage used: $(human_readable_size $(get_current_size))/$(human_readable_size $(get_config "MAX_SIZE")) ($(($(get_current_size) / $(get_config "MAX_SIZE")))%)" # wrong current size
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
    local id original_name original_path deletion_date file_size file_type permissions owner;
    IFS="$METADATA_DELIMITER" read -r id original_name original_path deletion_date file_size file_type permissions owner <<< "$metadata_line"
    [ -z "$original_path" ] && {
        echo -e "${RED}Error: Couldn't get metadata of file with ID '$file_id'${NC}"
        return 1
    }
    # Check if original path exists
    local dir_path=$(dirname "$original_path")
    [ ! -d "$dir_path" ] && {
        mkdir -p "$dir_path"
    }
    #chmod u+rwx "$dir_path"
    # Move file back to original path
    [ -e "$original_path" ] && {
        echo -e "${YELLOW}Warning: Original path '$original_path' already exists.${NC}"
        echo -n "Do you want to overwrite?"
        #TODO: Add change name option
        confirm_action || {
            echo "Restore cancelled."
            return 1
        }
    }
    mv "$FILES_DIR/$file_id" "$original_path" || {
        echo -e "${RED}Error: Failed to restore file to '$original_path'${NC}"
        return 1
    }
    # Restore original permissions
    chmod "$permissions" "$original_path"
    # Restore original owner
    chown "$owner" "$original_path" 2>/dev/null
    # Remove entry from metadata
    grep -v "$file_id" "$METADATA_FILE" > "$METADATA_FILE.temp"
    mv "$METADATA_FILE.temp" "$METADATA_FILE"
    [ $(grep -c "^$file_id" "$METADATA_FILE") -ne 0 ] && {
        echo -e "${RED}Error: Failed to update metadata after restoring file${NC}"
        return 1
    }

    get_log "restore_file - File with ID: $file_id restored to $original_path."
    echo -e "${GREEN}File restored to '$original_path' successfully.${NC}"
    return 0
}

#################################################
# Function: empty_recyclebin
# Description: Permanently deletes all items
# Parameters: None
# Returns: 0 on success
#################################################
empty_recyclebin() {
    # initialize local variables (to avoid conflits with other functions)
    local id="" # id form a specific file/directory to be deleted
    local force="false"
    local deleted_files=""
    local confirmation=""
    local file_path=""
    local metadata_line=""
    local file_name=""
    for argument in "$@"; do # $@ gets all arguments after 'empty' (for example: recycle_bin.sh empty 1696234567_abc123 -> retrieves "1696234567_abc123")
        if [ "$argument" == "--force" ]; then
            force="true"
            break
        else
            id="$argument"
        fi
    done

    # Check if specific ID was provided
    if [ -n "$id" ]; then
        file_path="$FILES_DIR/$id"
        if [ ! -e "$file_path" ]; then
            echo -e "${RED}Error: No file with id '$id' found in recycle bin${NC}"
            return 1
        fi
    fi

    # Ask for confirmation unless --force is used
    if [ "$force" != "true" ]; then
        echo -e "${YELLOW}Warning!!! Are you sure you want to delete ${id:+this file/directory from}${id:-all contents of} the Recycle bin?${NC}\nType 'Y' to confirm:"
        read -r confirmation
        if [ "${confirmation^^}" != "Y" ]; then
            echo -e "${RED}Operation cancelled by the user.${NC}"
            return 1
        fi
    fi

    if [ -n "$id" ]; then
        # Delete specific file
        deleted_file=$(grep "^$id" "$METADATA_FILE" | cut -d"$METADATA_DELIMITER" -f2)
        rm -rf "$file_path"
        grep -v "^$id" "$METADATA_FILE" > "$METADATA_FILE.tmp"
        mv "$METADATA_FILE.tmp" "$METADATA_FILE"
        echo -e "${GREEN}File/Directory deleted:${NC}"
        echo "$deleted_file"
    else
        # Delete all files
        deleted_files=$(tail -n +3 "$METADATA_FILE" | cut -d"$METADATA_DELIMITER" -f2)
        rm -rf "$FILES_DIR"/*
        echo "# Recycle Bin Metadata" > "$METADATA_FILE"
        echo "$(join_by "$METADATA_DELIMITER" $METADATA_HEADER_FIELDS)" >> "$METADATA_FILE"
        echo -e "${GREEN}Files/Directories deleted:${NC}"
        echo "$deleted_files"
        echo -e "${GREEN}Recycle bin successfully emptied.${NC}"
    fi
    return 0

    return 1
}

#################################################
# Function: search_recycled
# Description: Searches for files in recycle bin
# Parameters: $1 - search pattern
# Returns: 0 on success, 1 on no matches
#################################################
search_recycled() {
    # Check parameter count
    [ $# -eq 0 ] && { 
        echo -e "${RED}No arguments specified. Usage $SCRIPT [-i] <file_name> ${NC}" 
        return 1
    }
    local grep_flag=""
    [ "$1" == "-i" ] && grep_flag="i" && shift
    local lines=$(tail -n +3 "$METADATA_FILE")
    [ -z "$lines" ] && { echo "No files in recycle bin"; return 1; }
    local pattern="$1"
    local had_matches=false
    while IFS="\n" read -r line; do
        IFS="$METADATA_DELIMITER" read -r id original_name original_path deletion_date file_size file_type permissions owner <<< "$line"
        if echo "$original_name" | grep -qE"$grep_flag" "$pattern" || echo "$original_path" | grep -qE"$grep_flag" "$pattern"; then
            if ! $had_matches; then
                printf "%-20s %-30s %-20s %-10s\n" "ID" "ORIGINAL NAME" "DELETION DATE" "SIZE"
                had_matches=true
            fi
            [ "$original_name" == "${original_name:0:25}" ] || original_name="${original_name:0:22}..."
            printf "%-20s %-30s %-20s %-10s\n" "$id" "$original_name" "$deletion_date" "$(human_readable_size "$file_size")"
        fi
    done <<< "$lines"
    $had_matches || {
        echo "No matches found for pattern '$pattern'" # TODO: add verbose parameter
        return 1
    }
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
    $SCRIPT [OPTION] [ARGUMENTS]

OPTIONS:
    delete <file> <...files>    Move file/directory to recycle bin
    list                        List all items in recycle bin
    restore <id>                Restore file by ID
    search <pattern>            Search for files by name
    empty                       Empty recycle bin permanently
    help|-h|--help              Display this help message

EXAMPLES:
    $SCRIPT delete myfile.txt anotherfile.txt
    $SCRIPT list
    $SCRIPT restore 1696234567_abc123
    $SCRIPT search "*.pdf"
    $SCRIPT empty
    $SCRIPT -h

CONFIGURATION:
    Configuration file is located at: $CONFIG_FILE
    You can edit MAX_SIZE and RETENTION_DAYS parameters there.

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

    local command="$1"
    [ -z "$command" ] && command="help"
    shift

    # Parse command line arguments
    case "$command" in
        delete)
            delete_file "$@"
            ;;
        list)
            list_recycled "$@"
            ;;
        restore)
            restore_file "$@"
            ;;
        search)
            search_recycled "$@"
            ;;
        empty)
            empty_recyclebin "$@"
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
# Function: get_metadata
# Description: (Helper) Generate metadata for a file or directory
# Parameters: $1 - path to file
# Returns: 0 on success
#################################################
get_metadata() {
    local file="$1"
    local id original_name original_path deletion_date file_size file_type permissions owner

    id=$(generate_unique_id)
    original_name=$(basename "$file")
    original_path=$(realpath "$file")
    deletion_date=$(date "+%Y-%m-%d %H:%M:%S")
    file_size=$(stat -c %s "$file")
    [ -d "$file" ] && file_size=$(du -sb "$file" | awk '{print $1}') || 
    file_type="f"
    [ -d "$file" ] && file_type="d"
    permissions=$(stat -c "%a" "$file")
    owner=$(stat -c %U:%G "$file")

    # TODO: Use arrays
    echo $(join_by "$METADATA_DELIMITER" "$id" "$original_name" "$original_path" "$deletion_date" "$file_size" "$file_type" "$permissions" "$owner")
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
# Function: get_log
# Description: (Helper) Get log entry
# Parameters: None
# Returns: prints log 
#################################################

get_log () {
    touch $LOG_FILE
    echo "[$(date "+%Y-%m-%d %H:%M:%S")]" "$1" >> "$LOG_FILE"
}

#################################################
# Function: get_current_size
# Description: (Helper) Get current size of recycle bin
# Parameters: None
# Returns: Prints size in bytes to stdout
#################################################
get_current_size() {
    local total_size=0
    tail -n +3 "$METADATA_FILE" | while read -r line; do
        IFS="$METADATA_DELIMITER" read -r id original_name original_path deletion_date file_size file_type permissions owner <<< "$line"
        total_size=$(($total_size + $file_size))
    done
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