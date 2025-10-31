#!/bin/bash

# Test Suite for Recycle Bin System

# Global Configuration
RECYCLE_BIN_DIR="$HOME/.recycle_bin"
FILES_DIR="$RECYCLE_BIN_DIR/files"
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"
CONFIG_FILE="$RECYCLE_BIN_DIR/config"
METADATA_DELIMITER='|'

SCRIPT="$(dirname "$0")/recycle_bin.sh"
TEST_DIR="$(dirname "$0")/test_data"
PASS=0
FAIL=0
STDOUT="/dev/null"
[ -n "$1" ] && [ "$1" == "-v" ] && STDOUT="/dev/stdout"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test Helper Functions
setup() {
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    rm -rf ~/.recycle_bin
}

teardown() {
    rm -rf "$TEST_DIR"
    rm -rf ~/.recycle_bin
}

assert_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $1"
        ((PASS++))
    else
        echo -e "${RED}✗ FAIL${NC}: $1"
        ((FAIL++))
    fi
}

assert_fail() {
    if [ $? -ne 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $1"
        ((PASS++))
    else
        echo -e "${RED}✗ FAIL${NC}: $1"
        ((FAIL++))
    fi
}

echo "========================================="
echo "  Recycle Bin Test Suite"
echo "========================================="

# Test Basic Functionality
echo -e "\n${BLUE}# Basic Functionality Tests${NC}"

test_initialize_recycle_bin_structure() {
    echo -e "\n${BLUE}_______ Test: Initialization _______${NC}"
    setup > "$STDOUT"
    $SCRIPT > "$STDOUT"
    assert_success "Initialize recycle bin"
    [ -d "$RECYCLE_BIN_DIR" ] && echo "✓ Directory created" || echo "✗ Directory missing"
    [ -d "$FILES_DIR" ] && echo "✓ Files directory created" || echo "✗ Files directory missing"
    [ -f "$METADATA_FILE" ] && echo "✓ Metadata file created" || echo "✗ Metadata file missing"
    [ -f "$CONFIG_FILE" ] && echo "✓ Config file created" || echo "✗ Config file missing"
}
test_initialize_recycle_bin_structure #1

test_delete_single_file() {
    echo -e "\n${BLUE}_______ Test: Delete File _______${NC}"
    setup > "$STDOUT"
    echo "test content" > "$TEST_DIR/test !@#$%^&*() file.txt" # spaces and special characters in the name
    $SCRIPT delete "$TEST_DIR/test !@#$%^&*() file.txt" > "$STDOUT"
    assert_success "Delete existing file"
    [ ! -f "$TEST_DIR/test !@#$%^&*() file.txt" ] && echo "✓ File removed from original location" || echo "✗ File still exists in original location"
}
test_delete_single_file #2

test_delete_multiple_files_in_one_command() {
    echo -e "\n${BLUE}_______ Test: Delete Multiple Files _______${NC}"
    setup > "$STDOUT"
    for i in {1..3}; do
        echo "content $i" > "$TEST_DIR/file$i.txt"
    done
    mkdir "$TEST_DIR/dir1"
    echo "content" > "$TEST_DIR/dir1/file.txt"
    mkdir "$TEST_DIR/dir2"
    echo "content" > "$TEST_DIR/dir2/file.txt"

    $SCRIPT delete "$TEST_DIR"/file1.txt "$TEST_DIR"/file2.txt "$TEST_DIR"/file3.txt "$TEST_DIR/dir1/file.txt" "$TEST_DIR/dir2/file.txt" > "$STDOUT"
    assert_success "Delete multiple files"
    for i in {1..3}; do
        [ ! -f "$TEST_DIR/file$i.txt" ] && echo "✓ file$i.txt removed from original location" || echo "✗ file$i.txt still exists in original location"
    done
    [ "$TEST_DIR/dir1/file.txt" ] && echo "✓ dir1/file.txt removed from original location" || echo "✗ dir1/file.txt still exists in original location"
    [ "$TEST_DIR/dir2/file.txt" ] && echo "✓ dir2/file.txt removed from original location" || echo "✗ dir2/file.txt still exists in original location"
}
test_delete_multiple_files_in_one_command #3

test_delete_empty_directory() {
    echo -e "\n${BLUE}_______ Test: Delete Empty Directory _______${NC}"
    setup > "$STDOUT"
    mkdir -p "$TEST_DIR/empty_dir"
    $SCRIPT delete "$TEST_DIR/empty_dir" > "$STDOUT"
    assert_success "Delete empty directory"
    [ ! -d "$TEST_DIR/empty_dir" ] && echo "✓ Directory removed from original location" || echo "✗ Directory still exists in original location"
}
test_delete_empty_directory #4

test_delete_directory_with_contents_recursive() {
    echo -e "\n${BLUE}_______ Test: Delete Directory with Files _______${NC}"
    setup > "$STDOUT"
    mkdir -p "$TEST_DIR/dir_with_files"
    for i in {1..10}; do
        echo "content $i" > "$TEST_DIR/dir_with_files/file$i.txt"
    done
    $SCRIPT delete "$TEST_DIR/dir_with_files" > "$STDOUT"
    assert_success "Delete directory with files"
    [ ! -d "$TEST_DIR/dir_with_files" ] && echo "✓ Directory removed from original location" || echo "✗ Directory still exists in original location"
}
test_delete_directory_with_contents_recursive #5

test_list_empty_recycle_bin() {
    echo -e "\n${BLUE}_______ Test: List Empty Bin _______${NC}"
    setup > "$STDOUT"
    [[ $($SCRIPT list | head -n 1) == "Recycle bin is empty" ]]
    assert_success "List empty recycle bin"
    [ $(wc -l < "$METADATA_FILE") -le 2 ] && echo "✓ Metadata file is empty" || echo "✗ Metadata file not empty"
    [ $(ls -A "$FILES_DIR" | wc -l) -eq 0 ] && echo "✓ Files directory is empty" || echo "✗ Files directory not empty"
}
test_list_empty_recycle_bin #6

test_list_recycle_bin_with_items() {
    echo -e "\n${BLUE}_______ Test: List Bin with Items _______${NC}"
    setup > "$STDOUT"
    echo "item1" > "$TEST_DIR/item1.txt"
    echo "item2" > "$TEST_DIR/item123456789009876543211234567890.txt"
    $SCRIPT delete "$TEST_DIR/item1.txt" "$TEST_DIR/item123456789009876543211234567890.txt" > "$STDOUT"

    result=$($SCRIPT list)
    assert_success "List recycle bin with items"
    [ "$(echo "$result" | grep "Total items:" | awk '{print $3}')" == "2" ] && echo "✓ Correct number of items listed" || echo "✗ Incorrect number of items listed"
}
test_list_recycle_bin_with_items #7

test_restore_single_file() {
    echo -e "\n${BLUE}_______ Test: Restore File _______${NC}"
    setup > "$STDOUT"
    echo "test" > "$TEST_DIR/.restore_test.txt"
    $SCRIPT delete "$TEST_DIR/.restore_test.txt" > "$STDOUT"

    ID=$($SCRIPT list | grep "restore_test" | awk '{print $1}')
    $SCRIPT restore "$ID" > "$STDOUT"
    assert_success "Restore file"
    [ -f "$TEST_DIR/.restore_test.txt" ] && echo "✓ File restored" || echo "✗ File not restored"
}
test_restore_single_file #8

test_restore_to_non-existent_original_path() {
    echo -e "\n${BLUE}_______ Test: Restore to Non-existent Directory _______${NC}"
    setup > "$STDOUT"
    mkdir -p "$TEST_DIR/restore_nonexistent"
    echo "test" > "$TEST_DIR/restore_nonexistent/test.txt"
    $SCRIPT delete "$TEST_DIR/restore_nonexistent/test.txt" > "$STDOUT"

    rm -rf "$TEST_DIR/restore_nonexistent"

    ID=$($SCRIPT list | grep "test.txt" | awk '{print $1}')
    $SCRIPT restore "$ID" > "$STDOUT"
    assert_success "Restore file to non-existent directory"
    [ -d "$TEST_DIR/restore_nonexistent" ] && echo "✓ Original directory recreated" || echo "✗ Original directory not recreated"
    [ -f "$TEST_DIR/restore_nonexistent/test.txt" ] && echo "✓ File restored to new directory" || echo "✗ File not restored to new directory"
}
test_restore_to_non-existent_original_path #9

test_empty_entire_recycle_bin() {
    echo -e "\n${BLUE}________Test: Emptying recycle bin with confirmation________${NC}"
    setup > "$STDOUT"

    echo "file A" > "$TEST_DIR/fileA.txt"
    echo "file B" > "$TEST_DIR/fileB.txt"
    echo "file C" > "$TEST_DIR/fileC.txt"

    $SCRIPT delete "$TEST_DIR/fileA.txt" "$TEST_DIR/fileB.txt" "$TEST_DIR/fileC.txt" > "$STDOUT"
    echo "Y" | $SCRIPT empty > "$STDOUT"
    assert_success "Empty recycle bin with confirmation"

    [ $(wc -l < "$METADATA_FILE") -le 2 ] && echo "✓ Metadata file is empty" || echo "✗ Metadata file not empty"
    [ $(ls -A "$FILES_DIR" | wc -l) -eq 0 ] && echo "✓ Files directory is empty" || echo "✗ Files directory not empty"
}
test_empty_entire_recycle_bin #10

test_search_for_existing_file() {
    echo -e "\n${BLUE}_______ Test: Search Existing Files with Case Match _______${NC}"
    setup > "$STDOUT"

    echo "search content" > "$TEST_DIR/search_test.txt"
    echo "search content" > "$TEST_DIR/Search_test.txt"
    mkdir "$TEST_DIR/another_search_test"
    echo "search content" > "$TEST_DIR/search_but_no_test.txt"
    $SCRIPT delete "$TEST_DIR/search_test.txt" "$TEST_DIR/Search_test.txt" "$TEST_DIR/another_search_test" "$TEST_DIR/search_but_no_test.txt" > "$STDOUT"

    pattern="search_test"
    result=$($SCRIPT search "$pattern")
    assert_success "Search existing files"
    echo "$result" > "$STDOUT"
    [ $(echo "$result" | tail -n +2 | grep -cE "$pattern") -eq 2 ] && echo "✓ Found matching files" || echo "✗ Wrong number of matching files found"
}
test_search_for_existing_file #11

test_search_for_non-existent_file() {
    echo -e "\n${BLUE}_______ Test: Search with no Matches _______${NC}"
    setup > "$STDOUT"

    echo "search content" > "$TEST_DIR/search_test.txt"
    mkdir "$TEST_DIR/another_search_test"
    echo "search content" > "$TEST_DIR/search_but_no_test.txt"
    $SCRIPT delete "$TEST_DIR/search_test.txt" "$TEST_DIR/another_search_test" "$TEST_DIR/search_but_no_test.txt" > "$STDOUT"

    pattern="Search_test"
    result=$($SCRIPT search "$pattern")
    assert_fail "Search with no matches"
    echo "$result" > "$STDOUT"
    [ "$(tail -n 1 <<< "$result")" == "No matches found for pattern '$pattern'" ] && echo "✓ No matching files found" || echo "✗ Found matching files"
}
test_search_for_non-existent_file #12

test_display_help_information() {
    echo -e "\n${BLUE}_______ Test: Display Help _______${NC}"
    setup > "$STDOUT"
    result=$($SCRIPT help)
    assert_success "Display help"
    [[ "$result" == *"Linux Recycle Bin - Usage Guide"* ]] && echo "✓ Help content displayed" || echo "✗ Help content missing"
}
test_display_help_information #13

# Test Edge Cases
echo -e "\n${YELLOW}# Test Edge Cases${NC}"

test_delete_nonexistent_file() {
    echo -e "\n${YELLOW}_______ Test: Delete Non-existent File _______${NC}"
    setup > "$STDOUT"
    $SCRIPT delete "$TEST_DIR/nonexistent.txt" > "$STDOUT"
    assert_fail "Delete Non-existent file"
}
test_delete_nonexistent_file #14

test_delete_file_without_permissions() {
    echo -e "\n${YELLOW}_______ Test: Delete File Without Permissions _______${NC}"
    setup > "$STDOUT"
    echo "file without permissions" > "$TEST_DIR/file_without_permissions.txt"
    chmod u-rw "$TEST_DIR/file_without_permissions.txt"
    $SCRIPT delete "$TEST_DIR/file_without_permissions.txt" > "$STDOUT"
    assert_fail "Delete File Without Permissions"
}
test_delete_file_without_permissions #15

test_restore_when_original_location_has_same_filename() {
    echo -e "\n${YELLOW}_______ Test: Restore When Original Location has Same Filename _______${NC}"
    setup > "$STDOUT"
    echo "file" > "$TEST_DIR/restore_test.txt"
    $SCRIPT delete "$TEST_DIR/restore_test.txt" > "$STDOUT"
    echo "file" > "$TEST_DIR/restore_test.txt"
    ID=$($SCRIPT list | grep "restore_test" | awk '{print $1}')
    echo "r" | $SCRIPT restore "$ID" > "$STDOUT" # r|restore|rename|o|overwrite return success
    assert_success "Restore When Original Location has Same Filename"
}
test_restore_when_original_location_has_same_filename

test_restore_with_ID_that_doesnt_exist() {
    echo -e "\n${YELLOW}_______ Test: Restore With ID That Doesn't Exist _______${NC}"
    setup > "$STDOUT"
    echo "file" > "$TEST_DIR/restore_test.txt"
    $SCRIPT delete "$TEST_DIR/restore_test.txt" > "$STDOUT"
    $SCRIPT restore nonexistent_ID > "$STDOUT"
    assert_fail "Restore With ID That Doesn't Exist"
}
test_restore_with_ID_that_doesnt_exist
setup

# Test Performance
echo -e "\n${PURPLE}# Performance Tests${NC}"

test_delete_100_files() {
    echo -e "\n${PURPLE}_______ Test: Delete 100 Files _______${NC}"
    setup > "$STDOUT"
    for i in {1..100}; do
        echo "$i {0..10}" > "$TEST_DIR/file$i.txt"
    done

    start_time=$(date +%s.%N)
    $SCRIPT delete "$TEST_DIR"/file1.txt "$TEST_DIR"/file{2..100}.txt > "$STDOUT"
    status=$?
    end_time=$(date +%s.%N)

    duration=$(awk -v s="$start_time" -v e="$end_time" 'BEGIN {printf "%.3f", e - s}')

    [ $status -eq 0 ]
    assert_success "Delete 100 files in $duration seconds"

    for i in {1..100}; do
        if [ -f "$TEST_DIR/file$i.txt" ]; then
            echo "✗ File file$i.txt still exists"
            return
        fi
    done
    echo "✓ All 100 files removed from original location"
}
test_delete_100_files

# Test Additional
echo -e "\n${CYAN}# Additional Tests${NC}"

test_delete_no_arguments() {
    echo -e "\n${CYAN}_______ Test: Delete with No Arguments _______${NC}"
    setup > "$STDOUT"
    $SCRIPT delete > "$STDOUT"
    assert_fail "Delete with no arguments"
}
test_delete_no_arguments

test_empty_force() {
    echo -e "\n${CYAN}________Test: Emptying recycle bin with --force________${NC}"
    setup > "$STDOUT"

    echo "file 1" > "$TEST_DIR/file1.txt"
    echo "file 2" > "$TEST_DIR/file2.txt"
    echo "file 3" > "$TEST_DIR/file3.txt"

    $SCRIPT delete "$TEST_DIR/file1.txt" "$TEST_DIR/file2.txt" "$TEST_DIR/file3.txt" > "$STDOUT"

    $SCRIPT empty --force > "$STDOUT"
    assert_success "Empty recycle bin with --force"

    [ $(wc -l < "$METADATA_FILE") -le 2 ] && echo "✓ Metadata file is empty" || echo "✗ Metadata file not empty"
    [ $(ls -A "$FILES_DIR" | wc -l) -eq 0 ] && echo "✓ Files directory is empty" || echo "✗ Files directory not empty"

}
test_empty_force

test_empty_specific_file_force() {
    echo -e "\n${CYAN}________Test: Emptying specific file from recycle bin with --force________${NC}"
    setup > "$STDOUT"

    echo "file A" > "$TEST_DIR/fileA.txt"
    echo "file B" > "$TEST_DIR/fileB.txt"
    echo "file C" > "$TEST_DIR/fileC.txt"

    $SCRIPT delete "$TEST_DIR/fileA.txt" "$TEST_DIR/fileB.txt" "$TEST_DIR/fileC.txt" > "$STDOUT"


    local file_id=$(sed -n '4p' "$METADATA_FILE" | cut -d"$METADATA_DELIMITER" -f1)

    $SCRIPT empty "$file_id" --force > "$STDOUT"
    assert_success "Empty specific file from recycle bin with --force"

    [ $(grep -c "^$file_id," "$METADATA_FILE") -eq 0 ] && echo "✓ Specific file metadata removed" || echo "✗ Specific file metadata still exists"
    [ ! -f "$FILES_DIR/$file_id" ] && echo "✓ Specific file removed from files directory" || echo "✗ Specific file still exists in files directory"
}
test_empty_specific_file_force

test_empty_specific_file() {
    echo -e "\n${CYAN}________Test: Emptying specific file from recycle bin with confirmation________${NC}"
    setup > "$STDOUT"

    echo "file A" > "$TEST_DIR/fileA.txt"
    echo "file B" > "$TEST_DIR/fileB.txt"
    echo "file C" > "$TEST_DIR/fileC.txt"

    $SCRIPT delete "$TEST_DIR/fileA.txt" "$TEST_DIR/fileB.txt" "$TEST_DIR/fileC.txt" > "$STDOUT"
    local file_id=$(sed -n '4p' "$METADATA_FILE" |  cut -d"$METADATA_DELIMITER" -f1)

    echo "Y" | $SCRIPT empty "$file_id" > "$STDOUT"
    assert_success "Empty specific file from recycle bin with confirmation"

    [ $(grep -c "^$file_id," "$METADATA_FILE") -eq 0 ] && echo "✓ Specific file metadata removed" || echo "✗ Specific file metadata still exists"
    [ ! -f "$FILES_DIR/$file_id" ] && echo "✓ Specific file removed from files directory" || echo "✗ Specific file still exists in files directory"
}
test_empty_specific_file

test_search_existing_files_ignore_case() {
    echo -e "\n${CYAN}_______ Test: Search Existing File with Ignore Case _______${NC}"
    setup > "$STDOUT"

    echo "search content" > "$TEST_DIR/search_test.txt"
    echo "search content" > "$TEST_DIR/Search_test.txt"
    mkdir "$TEST_DIR/another_search_test"
    echo "search content" > "$TEST_DIR/search_but_no_test.txt"
    $SCRIPT delete "$TEST_DIR/search_test.txt" "$TEST_DIR/Search_test.txt" "$TEST_DIR/another_search_test" "$TEST_DIR/search_but_no_test.txt" > "$STDOUT"

    pattern="search_test"
    result=$($SCRIPT search -i "$pattern")
    assert_success "Search existing files with ignore case"
    [ $(echo "$result" | tail -n +2 | grep -cEi "$pattern") -eq 3 ] && echo "✓ Found matching files" || echo "✗ Wrong number of matching files found"
}
test_search_existing_files_ignore_case

test_search_with_complex_pattern() {
    echo -e "\n${CYAN}_______ Test: Search with Complex Pattern _______${NC}"
    setup > "$STDOUT"

    echo "complex content" > "$TEST_DIR/begin_then_end.txt"
    mkdir "$TEST_DIR/begin_1234_end"
    echo "complex content" > "$TEST_DIR/begin_1234_end/file.txt"
    echo "complex content" > "$TEST_DIR/begin_9876_end.txt"
    echo "complex content" > "$TEST_DIR/begin_009a_end.txt"
    $SCRIPT delete "$TEST_DIR/begin_then_end.txt" "$TEST_DIR/begin_1234_end" "$TEST_DIR/begin_9876_end.txt" "$TEST_DIR/begin_009a_end.txt" > "$STDOUT"

    pattern="^[begin]+.*[0-8]{3}.*[dt]$"
    local result=$($SCRIPT search "$pattern") > "$STDOUT"
    assert_success "Search with complex pattern"
    [ $(echo "$result" | tail -n +2 | awk -F' +' '{print $2}' | grep -cE "$pattern") -eq 2 ] && echo "✓ Found matching files" || echo "✗ Wrong number of matching files found" # this validation doesn't work when pattern is only in ORIGINAL_PATH or FILENAME is too big 
}
test_search_with_complex_pattern

teardown

echo "========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "========================================="

[ $FAIL -eq 0 ] && exit 0 || exit 1

# probably cannot handle large files. doesn't have special treatment for symbolic links
