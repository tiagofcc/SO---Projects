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

    "./recycle_bin.sh list" to print out all the files inside teh recycle bin
    !!! FALTA --detailed !!!


    "./recycle_bin.sh restore <fileId>" to restore one file in the recycle bin

    "./recycle_bin.sh empty" to empty the recycle bin. Add "--force" and/or a <fileId> to skip confirmation or to empty only a specific file, respectively.

    "./recycle_bin.sh search <pattern>" to search for files in the recycle bin by matching their names against the specified pattern


[How to use with examples]

## Features
- [List of implemented features]
- [Mark optional features]

## Configuration
[How to configure settings]

## Examples
[Detailed usage examples with screenshots]

## Known Issues
[Any limitations or bugs]

## References
    GitHub Copilot was used to write or rewrite pieces of code
    
    StackOverflow post about getting Nth line from file - https://stackoverflow.com/questions/6022384/bash-tool-to-get-nth-line-from-a-file (30/10/2025)
    StackOverflow post about function to join strings with delimiter - https://stackoverflow.com/questions/1527049/how-can-i-join-elements-of-a-bash-array-into-a-delimited-string#17841619 (30/10/2025)
    (not used) Stack Exchange post about answering y automatically - https://unix.stackexchange.com/questions/512367/how-do-i-automatically-answer-y-in-bash-script (30/10/2025)
    StackOverflow post about changing the characters of a string from lowercase to uppercase - https://pt.stackoverflow.com/questions/422494/como-passar-o-valor-de-uma-vari%C3%A1vel-para-mai%C3%BAscula-ou-minuscula (30/10/2025)
    Ask Ubuntu post about incrementing a variable - https://askubuntu.com/questions/385528/how-to-increment-a-variable-in-bash
    GNU page on "Bash Conditional Expressions" - https://www.gnu.org/software/bash/manual/html_node/Bash-Conditional-Expressions.html (30/10/2025)
    Bash Commands page about reading lines into multiple variables - https://bashcommands.com/bash-read-lines-into-multiple-variables (30/10/2025)


    Reference manual (man) of the commands: echo, sed, tail, head, grep, bash, cut, 
[Resources used]