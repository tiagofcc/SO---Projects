#!/bin/bash 
 
RECYCLE_BIN_DIR="$HOME/.recycle_bin" 
FILES_DIR="$RECYCLE_BIN_DIR/files" 
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db" 
CONFIG_FILE="$RECYCLE_BIN_DIR/config" 
 

################################################# 
# Function: initialize_recyclebin 
# Description: Creates recycle bin directory structure 
# Parameters: None 
# Returns: 0 on success, 1 on failure 
################################################# 
initialize_recyclebin() { 
    if [ ! -d "$RECYCLE_BIN_DIR" ]; then 
        mkdir -p "$FILES_DIR" 
        touch "$METADATA_FILE" 
        echo "# Recycle Bin Metadata" > "$METADATA_FILE" 
        echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" >> "$METADATA_FILE" 
        echo "Recycle bin initialized at $RECYCLE_BIN_DIR" 
        return 0 
    fi 
    return 0 
}


main() { 
    initialize_recyclebin
} 
 
main "$@"