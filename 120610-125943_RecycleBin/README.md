# Linux Recycle Bin System

## Author
    120610 - João Pedro Martins Castro Silva (LEI)
    125943 - Tiago Francisco Carvalho Costa (LEI)

## Description
This project was developed as the first practical assignment of the curricular unit "Sistemas Operativos (SO) at the Universidade de Aveiro, by a team of two students. The main objective was to implement a working Recycle Bin in Linux, similar to the one in Windows, using Bash Shell Script as programming language.

In the course of the development, some practical principles of programming were explored, including:
- Safe file management practices;
- Metadata tracking and preservation;
- User data protection mechanisms;
- System programming fundamentals;
- Professional code organization.

The final solution supports functions such as delete, restore, empty, list and help. Metadata management was handled through a file named metadata.db with a CSV structure, where information about the files/directories in the recycle bin were stored. Automated testing was also implemented via the test_suite.sh file, ensuring the conformity of the pre-stablished requirements.

## Installation
    Run "./recycle_bin.sh" anywhere 
    Use "chmod +x recycle_bin.sh" before if you don't have permission to execute
    The Recycle Bin directory will be initialized your $HOME directory

## Usage
    "./recycle_bin.sh help" for available commands
    
    "./recycle_bin.sh delete <filename> <filename>" to delete one or more files or directories

    "./recycle_bin.sh list" to print out all the files inside the recycle bin. Add "--detailed" if you want a more information about the files inside the recycle bin

    "./recycle_bin.sh restore <fileId>" to restore one file in the recycle bin

    "./recycle_bin.sh empty" to empty the recycle bin. Add "--force" and/or a <fileId> to skip confirmation or to empty only a specific file, respectively.

    "./recycle_bin.sh search <pattern>" to search for files in the recycle bin by matching their original names and paths, using REGEX, against the specified pattern

## Features
- 1. Recycle Bin Initialization
- 2. File Deletion
- 3. Listing Contents
- 4. File Restoration
- 5. Search Functionality
- 6. Permanent Deletion
- 7. Help Guide

## Configuration
The configuration is handled primarily through a file called CONFIG_FILE, which is created during the initialize_recyclebin() function. This file stores key settings that control how the recycle bin behaves.

Default values of the CONFIG_FILE when initialize:
MAX_SIZE=104857600           # Maximum total size allowed in bytes (100 MB)
METADATA_DELIMITER=|         # Delimiter used in the metadata file

How to configure the configurations inside CONFIG_FILE:
1. Run any of the recycle_bin command;
2. Go to the path where CONFIG_FILE is stored - $HOME/.recycle_bin/ ;
3. Open CONFIG_FILE with any text editor;
4. Change the values inside.

## Examples
[Detailed usage examples with screenshots]

## Known Issues
1. Cannot restore files by name 
Restoration is only possible using the unique ID assigned at deletion. There's no support for restoring by filename.

2. Does not handle disk space issues
The system doesn’t check if there’s enough disk space before moving files to the recycle bin, which may cause failures.

3. Does not validate all parameters and return codes
Some functions lack proper checks for input validity and operation results, which can lead to unexpected behavior.

4. No verification for long filenames
The system hasn’t been tested with extremely long filenames, which may cause issues depending on the filesystem.

5. No verification for large files
Very large files might exceed limits or slow down operations, but the system doesn’t treat them differently.

6. Does not treat symbolic links differently
Symbolic links are handled like regular files, which may result in unintended deletions or broken references.

7. No check for restoring to read-only directories
If the original path is read-only, restoration may fail silently or without clear feedback.

8. Does not check for corrupted metadata
Although the system recreates the metadata file if missing, it doesn’t validate its integrity if present.

9. Does not handle all permission-denied errors
Some permission issues may not be caught or reported properly, leading to silent failures.

10. Concurrent operations may cause errors
The system isn’t designed for simultaneous access, which can lead to metadata corruption or race conditions.rs

## References
    GitHub Copilot was used to write or rewrite pieces of code
    
    StackOverflow post about getting Nth line from file - https://stackoverflow.com/questions/6022384/bash-tool-to-get-nth-line-from-a-file (30/10/2025)
    StackOverflow post about function to join strings with delimiter - https://stackoverflow.com/questions/1527049/how-can-i-join-elements-of-a-bash-array-into-a-delimited-string#17841619 (30/10/2025)
    (not used) Stack Exchange post about answering y automatically - https://unix.stackexchange.com/questions/512367/how-do-i-automatically-answer-y-in-bash-script (30/10/2025)
    StackOverflow post about changing the characters of a string from lowercase to uppercase - https://pt.stackoverflow.com/questions/422494/como-passar-o-valor-de-uma-vari%C3%A1vel-para-mai%C3%BAscula-ou-minuscula (30/10/2025)
    Ask Ubuntu post about incrementing a variable - https://askubuntu.com/questions/385528/how-to-increment-a-variable-in-bash
    Tratif (Blog) post about logging in Shell - https://blog.tratif.com/2023/01/09/bash-tips-1-logging-in-shell-scripts/
    GNU page on "Bash Conditional Expressions" - https://www.gnu.org/software/bash/manual/html_node/Bash-Conditional-Expressions.html (30/10/2025)
    Bash Commands page about reading lines into multiple variables - https://bashcommands.com/bash-read-lines-into-multiple-variables (30/10/2025)


    Reference manual (man) of the commands: echo, sed, tail, head, grep, bash, cut, date