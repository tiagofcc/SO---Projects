#!/bin/bash 


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
# Function: empty_recyclebin
# Description: Permanently deletes all items
# Parameters: None
# Returns: 0 on success
#################################################
empty_recyclebin() {
    # initialize local variables (to avoid conflits with other functions)
    local id="" # id form a specific file/directory to be deleted
    local force=false
    local deleted_files=""
    local confirmation=""
    local file_path=""
    local metadata_line=""
    local file_name=""

    for argument in "$@"; do # $@ gets all arguments after 'empty' (for example: recycle_bin.sh empty 1696234567_abc123 -> retrieves "1696234567_abc123")
        if [ "$argument" == "--force" ]; then
            force=true;
        else
            id="$argument"
        fi
    done

    if [ -z "$id" ]; then # verify if id is empty
        if [ "$force" = true ]; then # verify if force --force was used as argument
            rm -rf "$FILES_DIR"/* # removes all files in the recycle bin files dir

            local deleted_files=$(tail "$METADATA_FILE" -n +2 | cut -d"$METADATA_DELIMITER" -f2) # get all the deleted files names from the matadata file

            echo "# Recycle Bin Metadata" > "$METADATA_FILE"
            echo $(join_by $METADATA_DELIMITER $METADATA_HEADER_FIELDS) >> "$METADATA_FILE" # delete all metadata info and adds the default header

            
            echo "${GREEN}Files/Directories deleted:${NC}"
            echo "$deleted_files" # prints the names of all the deleted files

            echo -e "${GREEN}Recycle bin successfully emptied.${NC}" # success message
            return 0

        else # without --force argument
            read -p "${YELLOW}Warning!!! Are you sure you want to delete all contents of the Recycle bin?${NC}\nType 'Y' to confirm:" confirmation

            confirmation="${confirmation^^}" #converts case to uppercase

            if [ "$confirmation" != "Y" ]; then # if user didn't confirm with Y
                echo -e "${RED}Operation cancelled by the user.${NC}"
                return 1              
            fi

            # proceed if user wrote Y
            rm -rf "$FILES_DIR"/*

            deleted_files=$(tail "$METADATA_FILE" -n +2 | cut -d"$METADATA_DELIMITER" -f2)

            echo "# Recycle Bin Metadata" > "$METADATA_FILE"
            echo $(join_by $METADATA_DELIMITER $METADATA_HEADER_FIELDS) >> "$METADATA_FILE"

            echo "${GREEN}Files/Directories deleted:${NC}"
            echo "$deleted_files"

            echo -e "${GREEN}Recycle bin successfully emptied.${NC}"
            return 0
        fi

    else # if id is not empty
        if [ "$force" = true ]; then # with --force argument
            file_path="$FILES_DIR/$id" # path to the file/directory of the passed id

            if [ -f "$file_path" ] || [ -d "$file_path" ]; then # verify if file/directory exists in  files dir
                rm -rf "$file_path"

                deleted_file=$(grep "^$id$METADATA_DELIMITER" "$METADATA_FILE" | cut -d"$METADATA_DELIMITER" -f2) # get the original file's name by using the id as the search for the line and choosing the 2nd field

                grep -v "^$id$METADATA_DELIMITER" "$METADATA_FILE" > "$METADATA_FILE.tmp" # remove only the line with the passed id from the metadata and saving it to a temporary file
                mv "$METADATA_FILE.tmp" "$METADATA_FILE" # replace the old metadata with the new temporary file

                echo "${GREEN}File/Directory deleted:${NC}" 
                echo "$deleted_file"
                return 0
            else
                echo -e "${RED}Error: No file with id '$id' found in recycle bin${NC}"
                return 1
            fi
        else
            read -p "${YELLOW}Warning!!! Are you sure you want to delete this file/directory of the Recycle bin?${NC}\nType 'Y' to confirm:" confirmation
            confirmation="${confirmation^^}"

            if [ "$confirmation" != "Y" ]; then
                echo -e "${RED}Operation cancelled by the user.${NC}"
                return 1
            fi

            file_path="$FILES_DIR/$id"
            if [ -f "$file_path" ] || [ -d "$file_path" ]; then
                rm -rf "$file_path"

                deleted_file=$(grep "^$id$METADATA_DELIMITER" "$METADATA_FILE" | cut -d"$METADATA_DELIMITER" -f2)

                grep -v "^$id," "$METADATA_FILE" > "$METADATA_FILE.tmp"
                mv "$METADATA_FILE.tmp" "$METADATA_FILE"

                echo "${GREEN}File/Directory deleted:${NC} "
                echo "$deleted_file"
                return 0
            else
                echo -e "${RED}Error: No file with id '$id' found in recycle bin${NC}"
                return 1
            fi

        fi
    fi

    return 1
}



# Run Tests


test_empty_force() {
    echo -e "\n________Test: Emptying recycle bin with --force________"
    setup > /dev/null

    echo "file 1" > "$TEST_DIR/file1.txt"
    echo "file 2" > "$TEST_DIR/file2.txt"
    echo "file 3" > "$TEST_DIR/file3.txt"

    $SCRIPT delete "$TEST_DIR/file1.txt" "$TEST_DIR/file2.txt" "$TEST_DIR/file3.txt" > /dev/null

    $SCRIPT empty --force
    assert_success "Empty recycle bin with --force"

    [ $(wc -l < "$METADATA_FILE") -le 2 ] && echo "✓ Metadata file is empty" || echo "✗ Metadata file not empty"
    [ $(ls -A "$FILES_DIR" | wc -l) -eq 0 ] && echo "✓ Files directory is empty" || echo "✗ Files directory not empty"

}

test_empty() {
    echo -e "\n________Test: Emptying recycle bin with confirmation________"
    setup > /dev/null

    echo "file A" > "$TEST_DIR/fileA.txt"
    echo "file B" > "$TEST_DIR/fileB.txt"
    echo "file C" > "$TEST_DIR/fileC.txt"

    $SCRIPT delete "$TEST_DIR/fileA.txt" "$TEST_DIR/fileB.txt" "$TEST_DIR/fileC.txt" > /dev/null
    echo "Y" | $SCRIPT empty

    assert_success "Empty recycle bin with confirmation"

    [ $(wc -l < "$METADATA_FILE") -le 2 ] && echo "✓ Metadata file is empty" || echo "✗ Metadata file not empty"
    [ $(ls -A "$FILES_DIR" | wc -l) -eq 0 ] && echo "✓ Files directory is empty" || echo "✗ Files directory not empty"
}

test_empty_specific_file_force() {
    echo -e "\n________Test: Emptying specific file from recycle bin with --force________"
    setup > /dev/null

    echo "file A" > "$TEST_DIR/fileA.txt"
    echo "file B" > "$TEST_DIR/fileB.txt"
    echo "file C" > "$TEST_DIR/fileC.txt"

    $SCRIPT delete "$TEST_DIR/fileA.txt" "$TEST_DIR/fileB.txt" "$TEST_DIR/fileC.txt" > /dev/null


    local file_id=$(sed -n '4p' "$METADATA_FILE" |  cut -d"$METADATA_DELIMITER" -f1)

    $SCRIPT empty "$file_id" --force
    assert_success "Empty specific file from recycle bin with --force"

    [ $(grep -c "^$file_id$METADATA_DELIMITER" "$METADATA_FILE") -eq 0 ] && echo "✓ Specific file metadata removed" || echo "✗ Specific file metadata still exists"
    [ ! -f "$FILES_DIR/$file_id" ] && echo "✓ Specific file removed from files directory" || echo "✗ Specific file still exists in files directory"
}

test_empty_specific_file() {
    echo -e "\n________Test: Emptying specific file from recycle bin with confirmation________"
    setup > /dev/null

    echo "file A" > "$TEST_DIR/fileA.txt"
    echo "file B" > "$TEST_DIR/fileB.txt"
    echo "file C" > "$TEST_DIR/fileC.txt"

    $SCRIPT delete "$TEST_DIR/fileA.txt" "$TEST_DIR/fileB.txt" "$TEST_DIR/fileC.txt" > /dev/null

    local file_id=$(sed -n '4p' "$METADATA_FILE" |  cut -d"$METADATA_DELIMITER" -f1)

    echo "Y" | $SCRIPT empty "$file_id"
    assert_success "Empty specific file from recycle bin with confirmation"

    [ $(grep -c "^$file_id$METADATA_DELIMITER" "$METADATA_FILE") -eq 0 ] && echo "✓ Specific file metadata removed" || echo "✗ Specific file metadata still exists"
    [ ! -f "$FILES_DIR/$file_id" ] && echo "✓ Specific file removed from files directory" || echo "✗ Specific file still exists in files directory"
}