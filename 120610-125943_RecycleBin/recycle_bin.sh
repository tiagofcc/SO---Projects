#!/bin/bash

#################################################
# Linux Recycle Bin Simulation
# Author: João Pedro Silva -120610
# Author: Tiago Francisco Costa - 125943
# Date: 2025-10-31
# Description: Shell-based recycle bin system
# Version: 1.0
#################################################

# Global Configuration
RECYCLE_BIN_DIR="$HOME/.recycle_bin"
FILES_DIR="$RECYCLE_BIN_DIR/files"
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"
CONFIG_FILE="$RECYCLE_BIN_DIR/config"
LOG_FILE="$RECYCLE_BIN_DIR/recyclebin.log"
SCRIPT="$0"

# Color codes for output (optional)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

METADATA_DELIMITER=''
METADATA_HEADER_FIELDS="ID ORIGINAL_NAME ORIGINAL_PATH DELETION_DATE FILE_SIZE FILE_TYPE PERMISSIONS OWNER"

#==========================================================================#
#                              Main Functions                              #
#=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v#

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
        echo "METADATA_DELIMITER=|" >> "$CONFIG_FILE"
    }
    METADATA_DELIMITER=$(get_config "METADATA_DELIMITER")
    [[ ! -f "$METADATA_FILE" ]] && {
        echo "# Recycle Bin Metadata" > "$METADATA_FILE"
        echo $(join_by $METADATA_DELIMITER $METADATA_HEADER_FIELDS) >> "$METADATA_FILE"
    }
    [[ ! -f "$LOG_FILE" ]] && log "initialize_recyclebin - Recycle Bin initialized."
    return 0
}

#################################################
# Function: delete_file
# Description: Moves file/directory to recycle bin
# Parameters: $@ - paths to file/directory
# Returns: 0 on success, 1 on no files deleted
#################################################
delete_file() {
    # Validate input
    echo -n "Delete function called with arguments: "
    for arg in "$@"; do
        echo -n "'$arg' "
    done
    echo ""
    if (($# == 0)); then
        echo -e "${RED}Error: No file(s) specified${NC}"
        return 1
    fi
    local num_files_deleted=0
    local total_files=$#
    for file in "$@"; do
        # Check if filename has METADATA_DELIMITER
        [[ "$(realpath "$file")" == *"$METADATA_DELIMITER"* ]] && {
            echo -e "${RED}Error: Recycle bin cannot handle files with '"$METADATA_DELIMITER"' in their absolute path${NC}"
            continue
        }
        # Check if file exists
        [ ! -e "$file" ] && {
            echo -e "${RED}Error: File '$file' does not exist${NC}"
            continue
        }
        # Prevent deleting from recycle bin itself
        [[ "$(realpath "$file")" == "$(realpath "$RECYCLE_BIN_DIR")"* ]] && {
            echo -e "${YELLOW}Warning: Cannot delete files from recycle bin itself: '$file'${NC}"
            continue
        }
        # Prevent deleting script itself
        [ "$(realpath "$file")" == "$(realpath "$SCRIPT")" ] && {
            echo -e "${YELLOW}Warning: Cannot delete the recycle bin script itself: '$file'${NC}"
            continue
        }
        # Get metadata
        local metadata=$(get_metadata "$file")
        IFS="$METADATA_DELIMITER" read -r id original_name original_path deletion_date file_size file_type permissions owner <<< "$metadata"
        # Check if recycle bin has enough space
        local current_size=$(get_current_size)
        local max_size=$(get_config "MAX_SIZE")
        (( current_size + file_size > max_size )) && {
            echo -e "${RED}Error: Not enough space in recycle bin to delete '$file'${NC}"
            continue
        }
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
        move_to_recycle_bin "$file" "$id" || continue
        update_metadata "$metadata" || continue
        ((num_files_deleted++))

        log "delete_file - $original_name moved to recycle bin with ID: $id."


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
        while IFS="$METADATA_DELIMITER" read -r id original_name original_path deletion_date file_size file_type permissions owner; do
            echo "ID: $id"
            echo "ORIGINAL_NAME: $original_name"
            echo "ORIGINAL_PATH: $original_path"
            echo "DELETION_DATE: $deletion_date"
            echo "FILE_SIZE: $(human_readable_size "$file_size")"
            echo "FILE_TYPE: $file_type"
            echo "PERMISSIONS: $permissions"
            echo "OWNER: $owner"
            echo ""
        done < <(tail -n +3 "$METADATA_FILE")
    else
        printf "%-20s %-30s %-20s %-10s\n" "ID" "ORIGINAL NAME" "DELETION DATE" "SIZE"
        while IFS="$METADATA_DELIMITER" read -r id original_name original_path deletion_date file_size file_type permissions owner; do
            [ "$original_name" == "${original_name:0:25}" ] || original_name="${original_name:0:22}..."
            printf "%-20s %-30s %-20s %-10s\n" "$id" "$original_name" "$deletion_date" "$(human_readable_size "$file_size")"
        done < <(tail -n +3 "$METADATA_FILE")
    fi
    printf "%s\n" "--------------------------------------------------------------------------------"
    echo "Total items: $(( $(wc -l < "$METADATA_FILE") - 2 ))"
    echo "Storage used: $(human_readable_size $(get_current_size))/$(human_readable_size $(get_config "MAX_SIZE")) ($(($(get_current_size) / $(get_config "MAX_SIZE") * 100))%)" # wrong current size
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
    # Check if original parents exists
    local dir_path=$(dirname "$original_path")
    [ ! -d "$dir_path" ] && {
        mkdir -p "$dir_path"
    }
    # Check if original path already exists
    [ -e "$original_path" ] && {
        echo -e "${YELLOW}Warning: Original path '$original_path' already exists.${NC}"
        # Ask user how to proceed when original path exists
        while true; do
            echo "Choose action: [O]verwrite, [C]ancel, [R]estore with new name: "
            read -r choice
            case "${choice,,}" in
            o|overwrite)
                # Keep path
                echo "Overwriting $original_path"
                break
                ;;
            r|rename|restore)
                # Change path
                uid=$(generate_unique_id)
                base_name=$(basename "$original_path")
                dir_path=$(dirname "$original_path")
                original_path="$dir_path/${uid}_$base_name"
                echo "Restoring with new name $(basename "$original_path")"
                break
                ;;
            c|cancel)
                # Do not proceed
                echo "Restore cancelled."
                return 1
                ;;
            *)
                echo "Invalid option."
                ;;
            esac
        done
    }
    # Move file back to original path
    mv "$FILES_DIR/$file_id" "$original_path" || {
        echo -e "${RED}Error: Failed restore file to original path${NC}"
        return 1
    }
    # Restore original permissions
    chmod "$permissions" "$original_path" || {
        echo -e "${YELLOW}Warning: Failed to restore original permissions for '$original_path'${NC}"
    }
    # Restore original owner
    chown "$owner" "$original_path" || {
        echo -e "${YELLOW}Warning: Failed to restore original owner for '$original_path'${NC}"
    }
    # Remove entry from metadata
    grep -v "$file_id" "$METADATA_FILE" > "$METADATA_FILE.temp"
    mv "$METADATA_FILE.temp" "$METADATA_FILE"
    [ $(grep -c "^$file_id" "$METADATA_FILE") -ne 0 ] && {
        echo -e "${RED}Error: Failed to update metadata after restoring file${NC}"
        return 1
    }

    log "restore_file - File with ID: $file_id restored to $original_path."
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
        local deleted_file=$(grep "^$id" "$METADATA_FILE" | cut -d"$METADATA_DELIMITER" -f2)
        rm -rf "$file_path"
        grep -v "^$id" "$METADATA_FILE" > "$METADATA_FILE.tmp"
        mv "$METADATA_FILE.tmp" "$METADATA_FILE"
        echo -e "${GREEN}File/Directory deleted:${NC}"
        echo "$deleted_file"
        log "empty_recyclebin - File with ID: $id permanently deleted from recycle bin."
    else
        # Delete all files
        local deleted_files=$(tail -n +3 "$METADATA_FILE" | cut -d"$METADATA_DELIMITER" -f2)
        local deleted_file_ids=$(tail -n +3 "$METADATA_FILE" | cut -d"$METADATA_DELIMITER" -f1)
        rm -rf "$FILES_DIR"/*
        echo "# Recycle Bin Metadata" > "$METADATA_FILE"
        echo "$(join_by "$METADATA_DELIMITER" $METADATA_HEADER_FIELDS)" >> "$METADATA_FILE"
        echo -e "${GREEN}Files/Directories deleted:${NC}"
        echo "$deleted_files"
        echo -e "${GREEN}Recycle bin successfully emptied.${NC}"
        for file_id in $deleted_file_ids; do
            log "empty_recyclebin - File with ID: $file_id permanently deleted from recycle bin."
        done
    fi
    return 0
}

#################################################
# Function: search_recycled
# Description: Searches for files in recycle bin
# Parameters: $1 - search pattern
# Returns: 0 on success, 1 on no matches
#################################################
search_recycled() {
    echo -n "Search function called with arguments: "
    for arg in "$@"; do
        echo -n "'$arg' "
    done
    echo ""
    # Check parameter count
    [ $# -eq 0 ] && { 
        echo -e "${RED}No arguments specified. Usage $SCRIPT [-i] <pattern> ${NC}"
        return 1
    }
    # Check if METADATA_FILE has lines 
    local lines=$(tail -n +3 "$METADATA_FILE")
    [ -z "$lines" ] && { 
        echo "No files in recycle bin"
        return 1
    }
    local grep_flag=""
    [ "$1" == "-i" ] && { grep_flag="i"; shift; }
    # Check if pattern was specified
    local pattern="$1"
    [ -z "$pattern" ] && {
        echo -e "${RED}No pattern specified. Usage $SCRIPT [-i] <pattern> ${NC}"
        return 1
    }
    # Check if has matches and print table
    local has_matches=false
    while IFS="\n" read -r line; do
        IFS="$METADATA_DELIMITER" read -r id original_name original_path deletion_date file_size file_type permissions owner <<< "$line"
        if grep -qE"$grep_flag" "$pattern" <<< "$original_name" || grep -qE"$grep_flag" "$pattern" <<< "$original_path"; then
            if ! $has_matches; then
                printf "%-20s %-30s %-20s %-10s\n" "ID" "ORIGINAL NAME" "DELETION DATE" "SIZE"
                has_matches=true
            fi
            [ "$original_name" == "${original_name:0:25}" ] || original_name="${original_name:0:22}..."
            printf "%-20s %-30s %-20s %-10s\n" "$id" "$original_name" "$deletion_date" "$(human_readable_size "$file_size")"
        fi
    done <<< "$lines"
    $has_matches || {
        echo "No matches found for pattern '$pattern'"
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

NAME
    $SCRIPT - A shell-based recycle bin system for managing deleted files and directories.

USAGE:
    $SCRIPT <command> [options]
    <expression>        indicates required parameters
    [expression]        indicates optional parameters
    [<expression> ...]  indicates multiple optional parameters 

COMMANDS:
    delete <path> [<path> ...]  Move one or more files or directories to the recycle bin
    list [--detailed]           Show items in the recycle bin (use --detailed for full metadata)
    restore <id>                Restore the file or directory with the given ID
    search [-i] <pattern>       Search by original name or path. Uses REGEX. Use -i for case-insensitive matching
    empty [--force] [id]        Permanently delete all items or a specific item by ID. Use --force to skip confirmation
    help, -h, --help            Show this help message

EXAMPLES:
    $SCRIPT delete myfile.txt otherdir
    $SCRIPT list
    $SCRIPT list --detailed
    $SCRIPT restore 1696234567_ab12cd
    $SCRIPT search -i "report.*2025"
    $SCRIPT empty --force

NOTES:
    - Each recycled item receives a unique ID of the form <timestamp>_<random> (for example: 1696234567_ab12cd).
    - Metadata is stored in: $METADATA_FILE
    - Recycle bin storage and configuration:
            Directory: $RECYCLE_BIN_DIR
            Files area: $FILES_DIR
            Configuration file: $CONFIG_FILE
            Key config values: MAX_SIZE (bytes), METADATA_DELIMITER (character)

Behavior highlights:
    - 'delete' will skip files that cannot be accessed or would cause the recycle bin to exceed MAX_SIZE.
    - 'list --detailed' prints per-item metadata (original path, deletion date, size, type, permissions, owner).
    - 'restore' will attempt to recreate the original parent directory if it does not exist and will prompt before overwriting an existing file.
    - 'empty' without arguments removes all recycled items after confirmation; with an ID it removes only that item.

EOF
    return 0
}

#=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^#
#                              End Main Functions                              #
#==============================================================================#

#============================================================================#
#                              Helper Functions                              #
#=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v=v#

########################################################
# Function: generate_unique_id
# Description: () Generates unique ID for deleted files
# Parameters: None
# Returns: Prints unique ID to stdout
########################################################
generate_unique_id() {
    local timestamp=$(date +%s)
    local random=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
    echo "${timestamp}_${random}"
}

##################################################################
# Function: get_metadata
# Description: (Helper) Generate metadata for a file or directory
# Parameters: $1 - path to file
# Returns: 0 on success
##################################################################
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
  shift 2 && printf %s "$f" "${@/#/$d}"
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
# Function: log
# Description: (Helper) Log entry to log file
# Parameters: None
# Returns: prints log 
#################################################

log () {
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
    while read -r line; do
        IFS="$METADATA_DELIMITER" read -r id original_name original_path deletion_date file_size file_type permissions owner <<< "$line"
        total_size=$(($total_size + $file_size))
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
    grep "^$key=" "$CONFIG_FILE" | awk -F'=' '{print $2}'
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

# Execute main function with all arguments
main "$@"