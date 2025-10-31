### Metadata Schema Explanation

    The file metadata.db, located inside the .recycle_bin directory, is going to store all the information about the files inside the recycle bin.

    There are eight metadata fields, including:
        - ID;
        - ORIGINAL_NAME;
        - ORIGINAL_PATH;
        - DELETION_DATE;
        - FILE_SIZE;
        - FILE_TYPE;
        - PERMISSIONS;
        - OWNER;

    ID:
        Unique identifier (timestamp_randomstring format).

    ORIGINAL_NAME:
        Original filename or directory name.

    ORIGINAL_PATH:
        Complete absolute path of original location.

    DELETION_DATE:
        Timestamp when deleted (YYYY-MM-DD HH:MM:SS).

    FILE_SIZE:
        Size in bytes.

    FILE_TYPE:
        Either "file" or "directory".

    PERMISSIONS:
        Original permission bits.

    OWNER:
        Original owner and group.

    
    All fields are divided by a dinamic delimiter - METADATA_DELIMITER.

    The information about the METADATA_DELIMITER variable is stored in the config file inside the same directory as the metadata.db. This helps changing the delimiter if needed by only having to change it in that specific file.

    The METADATA_HEADER_FIELDS defines the order of the fields:

        METADATA_HEADER_FIELDS="ID ORIGINAL_NAME ORIGINAL_PATH DELETION_DATE FILE_SIZE FILE_TYPE PERMISSIONS OWNER"


    Example of a metadata line:
    METADATA_DELIMITER=|
    1761933797_b8of9s|123.txt|/home/user/Desktop/123.txt|2025-10-12 18:03:17|0|f|664|user:user

### Function descriptions

initialize_recyclebin() - responsible for the configuration and preparation of the recycle bin system environment. It ensures that all essential directories and files are created and properly configured before use. It creates the RECYCLE_BIN_DIR, FILES_DIR, CONFIG_FILE, METADATA_FILE and configures them all.

delete_file() - responsible for the moving (deleting) files or directories to the recycle bin and updates the metadata file with deleted file's information. This function can delete 1 or more files in one call and will skip files that cannot be accessed or would cause the recycle bin to exceed MAX_SIZE. Registers every operation in the log file and prints out the amount of files deleted.

list_recycled() - responsible for showing the files in the recycle bin, either in short or detailed mode. Checks for files in the files directory, read and present file's information and tells total number of files and amount of space occupied.

restore_file() - responsible for the restoration of files inside the recycle bin, using their Ids inside the metadata file. The restored file is sent to their original path location, and if there's no original path anymore, it creates the original location. After the restoration, it updates metadata, register the operation in the log file.

empty_recyclebin() - 

empty_recyclebin() - Permanently deletes all files in the recycle bin or a specific file by ID or name. Supports confirmation prompts and a --force mode for silent deletion.

search_recycled() - responsible for searching for files/directories inside the recycle bin based on a pattern given by the user, this patter can either be the original name or path. There is the case-insensitive matching mode, invoked by typping "-i"

search_recycled() - Searches the recycle bin metadata for files matching a given pattern (ID or partial name). Displays matching entries with basic metadata for user reference.

auto_cleanup() - Automatically deletes files from the recycle bin that exceed the configured age (AUTO_CLEANUP_DAYS). Updates metadata and logs the cleanup summary including space freed.

show_statistics() - Displays summary statistics about the recycle bin, including total items, total size, usage percentage, file type breakdown, deletion date range, and average file size.