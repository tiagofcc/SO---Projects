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

initialize_recyclebin() – Responsible for the configuration and preparation of the recycle bin system environment. It ensures that all essential directories and files are created and properly configured before use. It creates the RECYCLE_BIN_DIR, FILES_DIR, CONFIG_FILE, METADATA_FILE and configures them all.

delete_file() – Responsible for moving (deleting) files or directories to the recycle bin and updating the metadata file with the deleted file's information. This function can delete one or more files in a single call and will skip files that cannot be accessed or would cause the recycle bin to exceed MAX_SIZE. It registers every operation in the log file and prints out the number of files deleted.

list_recycled() – Responsible for showing the files in the recycle bin, either in short or detailed mode. It checks for files in the files directory, reads and presents file information, and reports the total number of files and the amount of space occupied.

restore_file() – Responsible for the restoration of files inside the recycle bin, using their IDs from the metadata file. The restored file is sent to its original path location, and if the original path no longer exists, it creates the original location. After the restoration, it updates the metadata and registers the operation in the log file.

empty_recyclebin() – Responsible for permanently deleting files inside the recycle bin. It can either empty the whole recycle bin (if not specified) or delete one file (specified by ID). It also has the "--force" option that skips confirmation when active.

search_recycled() – Responsible for searching for files/directories inside the recycle bin based on a pattern given by the user. This pattern can be either the original name or path. There is a case-insensitive matching mode, invoked by typing "-i". If matches are found, it displays a table with the ID, name, deletion date, and size of each file; if not, it lets the user know that no matches were found.

display_help() – Responsible for guiding the user by printing a complete guide to the recycle bin system, explaining commands, required and optional parameters, practical examples, and notes on internal workings. It details every command and highlights notable behavior.

