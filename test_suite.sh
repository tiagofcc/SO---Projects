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

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Test Helper Functions
setup() {
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

# Basic Functionality Tests
test_initialization() {
    echo -e "\n_______ Test: Initialization _______"
    setup > /dev/null
    $SCRIPT help > /dev/null
    assert_success "Initialize recycle bin"
    [ -d "$RECYCLE_BIN_DIR" ] && echo "✓ Directory created" || echo "✗ Directory missing"
    [ -d "$FILES_DIR" ] && echo "✓ Files directory created" || echo "✗ Files directory missing"
    [ -f "$METADATA_FILE" ] && echo "✓ Metadata file created" || echo "✗ Metadata file missing"
    [ -f "$CONFIG_FILE" ] && echo "✓ Config file created" || echo "✗ Config file missing"
}
test_initialization #1

test_delete_file() {
    echo -e "\n_______ Test: Delete File _______"
    setup > /dev/null
    echo "test content" > "$TEST_DIR/test.txt"
    $SCRIPT delete "$TEST_DIR/test.txt" > /dev/null
    assert_success "Delete existing file"
    [ ! -f "$TEST_DIR/test.txt" ] && echo "✓ File removed from original location" || echo "✗ File still exists in original location"
}
test_delete_file #2

test_delete_multiple_files() {
    echo -e "\n_______ Test: Delete Multiple Files _______"
    setup > /dev/null
    for i in {1..3}; do
        echo "content $i" > "$TEST_DIR/file$i.txt"
    done
    $SCRIPT delete "$TEST_DIR"/file1.txt "$TEST_DIR"/file2.txt "$TEST_DIR"/file3.txt > /dev/null
    assert_success "Delete multiple files"
    for i in {1..3}; do
        [ ! -f "$TEST_DIR/file$i.txt" ] && echo "✓ file$i.txt removed from original location" || echo "✗ file$i.txt still exists in original location"
    done
}
test_delete_multiple_files #3

test_delete_empty_directory() {
    echo -e "\n_______ Test: Delete Empty Directory _______"
    setup > /dev/null
    mkdir -p "$TEST_DIR/empty_dir"
    $SCRIPT delete "$TEST_DIR/empty_dir" > /dev/null
    assert_success "Delete empty directory"
    [ ! -d "$TEST_DIR/empty_dir" ] && echo "✓ Directory removed from original location" || echo "✗ Directory still exists in original location"
}
test_delete_empty_directory #4

test_delete_directory_with_files() {
    echo -e "\n_______ Test: Delete Directory with Files _______"
    setup > /dev/null
    mkdir -p "$TEST_DIR/dir_with_files"
    for i in {1..10}; do
        echo "content $i" > "$TEST_DIR/dir_with_files/file$i.txt"
    done
    $SCRIPT delete "$TEST_DIR/dir_with_files" > /dev/null
    assert_success "Delete directory with files"
    [ ! -d "$TEST_DIR/dir_with_files" ] && echo "✓ Directory removed from original location" || echo "✗ Directory still exists in original location"
}
test_delete_directory_with_files #5

test_list_empty_bin() {
    echo -e "\n_______ Test: List Empty Bin _______"
    setup > /dev/null
    $SCRIPT list | head -n 1 > /dev/null
    [[ $($SCRIPT list | head -n 1) == "Recycle bin is empty" ]]
    assert_success "List empty recycle bin"
    [ $(wc -l < "$METADATA_FILE") -le 2 ] && echo "✓ Metadata file is empty" || echo "✗ Metadata file not empty"
    [ $(ls -A "$FILES_DIR" | wc -l) -eq 0 ] && echo "✓ Files directory is empty" || echo "✗ Files directory not empty"
}
test_list_empty_bin #6

test_list_bin_with_items() {
    echo -e "\n_______ Test: List Bin with Items _______"
    setup > /dev/null
    echo "item1" > "$TEST_DIR/item1.txt"
    echo "item2" > "$TEST_DIR/item123456789009876543211234567890.txt"
    $SCRIPT delete "$TEST_DIR/item1.txt" "$TEST_DIR/item123456789009876543211234567890.txt" > /dev/null

    result=$($SCRIPT list)
    assert_success "List recycle bin with items"
    [ "$(echo "$result" | grep "Total items:" | awk '{print $3}')" == "2" ] && echo "✓ Correct number of items listed" || echo "✗ Incorrect number of items listed"
}
test_list_bin_with_items #7

test_restore_file() {
    echo -e "\n_______ Test: Restore File _______"
    setup > /dev/null
    echo "test" > "$TEST_DIR/restore_test.txt"
    $SCRIPT delete "$TEST_DIR/restore_test.txt" > /dev/null

    # Get file ID from list
    ID=$($SCRIPT list | grep "restore_test" | awk '{print $1}')
    $SCRIPT restore "$ID" > /dev/null
    assert_success "Restore file"
    [ -f "$TEST_DIR/restore_test.txt" ] && echo "✓ File restored" || echo "✗ File not restored"
}
test_restore_file #8

test_restore_to_nonexistent_directory() {
    echo -e "\n_______ Test: Restore to Non-existent Directory _______"
    setup > /dev/null
    mkdir -p "$TEST_DIR/restore_nonexistent"
    echo "test" > "$TEST_DIR/restore_nonexistent/test.txt"
    $SCRIPT delete "$TEST_DIR/restore_nonexistent/test.txt" > /dev/null

    # Remove original directory
    rm -rf "$TEST_DIR/restore_nonexistent"

    # Get file ID from list
    ID=$($SCRIPT list | grep "test.txt" | awk '{print $1}')
    $SCRIPT restore "$ID" > /dev/null
    assert_success "Restore file to non-existent directory"
    [ -d "$TEST_DIR/restore_nonexistent" ] && echo "✓ Original directory recreated" || echo "✗ Original directory not recreated"
    [ -f "$TEST_DIR/restore_nonexistent/test.txt" ] && echo "✓ File restored to new directory" || echo "✗ File not restored to new directory"
}
test_restore_to_nonexistent_directory #9

test_empty() {
    echo -e "\n________Test: Emptying recycle bin with confirmation________"
    setup > /dev/null

    echo "file A" > "$TEST_DIR/fileA.txt"
    echo "file B" > "$TEST_DIR/fileB.txt"
    echo "file C" > "$TEST_DIR/fileC.txt"

    $SCRIPT delete "$TEST_DIR/fileA.txt" "$TEST_DIR/fileB.txt" "$TEST_DIR/fileC.txt" > /dev/null
    echo "Y" | $SCRIPT empty > /dev/null

    assert_success "Empty recycle bin with confirmation"

    [ $(wc -l < "$METADATA_FILE") -le 2 ] && echo "✓ Metadata file is empty" || echo "✗ Metadata file not empty"
    [ $(ls -A "$FILES_DIR" | wc -l) -eq 0 ] && echo "✓ Files directory is empty" || echo "✗ Files directory not empty"
}
test_empty #10

test_search_existing_files_default() {
    echo -e "\n_______ Test: Search Existing Files with Case Match _______"
    setup > /dev/null

    echo "search content" > "$TEST_DIR/search_test.txt"
    $SCRIPT delete "$TEST_DIR/search_test.txt" > /dev/null

    echo "search content" > "$TEST_DIR/Search_test.txt"
    $SCRIPT delete "$TEST_DIR/Search_test.txt" > /dev/null

    mkdir "$TEST_DIR/another_search_test"
    $SCRIPT delete "$TEST_DIR/another_search_test" > /dev/null

    echo "search content" > "$TEST_DIR/search_but_no_test.txt"
    $SCRIPT delete "$TEST_DIR/search_but_no_test.txt" > /dev/null

    pattern="search_test"
    result=$($SCRIPT search "$pattern")
    assert_success "Search existing files"
    [ $(echo "$result" | tail -n +2 | grep -cE "$pattern") -eq 2 ] && echo "✓ Found matching files" || echo "✗ Wrong number of matching files found"
}
test_search_existing_files_default #11

test_search_nonexistent_file() {
    echo -e "\n_______ Test: Search with No Matches _______"
    setup > /dev/null

    echo "search content" > "$TEST_DIR/search_test.txt"
    $SCRIPT delete "$TEST_DIR/search_test.txt" > /dev/null

    echo "search content" > "$TEST_DIR/search_test.txt"
    $SCRIPT delete "$TEST_DIR/search_test.txt" > /dev/null

    mkdir "$TEST_DIR/another_search_test"
    $SCRIPT delete "$TEST_DIR/another_search_test" > /dev/null

    echo "search content" > "$TEST_DIR/search_but_no_test.txt"
    $SCRIPT delete "$TEST_DIR/search_but_no_test.txt" > /dev/null

    pattern="Search_test"
    result=$($SCRIPT search "$pattern")
    assert_fail "Search with no matches"
    [ "$result" == "No matches found for pattern '$pattern'" ] && echo "✓ No matching files found" || echo "✗ Found matching files"
}
test_search_nonexistent_file #12

test_display_help() {
    echo -e "\n_______ Test: Display Help _______"
    setup > /dev/null
    result=$($SCRIPT help)
    assert_success "Display help"
    [[ "$result" == *"Linux Recycle Bin - Usage Guide"* ]] && echo "✓ Help content displayed" || echo "✗ Help content missing"
}
test_display_help #13

# Test Edge Cases

test_delete_100_files() {
    echo -e "\n_______ Test: Delete 100 Files _______"
    setup > /dev/null
    for i in {1..100}; do
        echo "$i {0..5}" > "$TEST_DIR/file$i.txt"
    done
    $SCRIPT delete "$TEST_DIR"/file1.txt "$TEST_DIR/file"{2..100}.txt > /dev/null
    assert_success "Delete 100 files"
    for i in {1..100}; do
        [ ! -f "$TEST_DIR/file$i.txt" ] || { echo "✗ File file$i.txt still exists"; return; }
    done
    echo "✓ All 100 files removed from original location"
}
# test_delete_100_files

test_delete_no_arguments() {
    echo -e "\n_______ Test: Delete with No Arguments _______"
    setup > /dev/null
    $SCRIPT delete > /dev/null
    assert_fail "Delete with no arguments"
}
test_delete_no_arguments

test_delete_nonexistent_file() {
    echo -e "\n_______ Test: Delete Non-existent File _______"
    setup > /dev/null
    $SCRIPT delete "$TEST_DIR/nonexistent.txt" > /dev/null
    assert_fail "Delete non-existent file"
}
test_delete_nonexistent_file

test_empty_force() {
    echo -e "\n________Test: Emptying recycle bin with --force________"
    setup > /dev/null

    echo "file 1" > "$TEST_DIR/file1.txt"
    echo "file 2" > "$TEST_DIR/file2.txt"
    echo "file 3" > "$TEST_DIR/file3.txt"

    $SCRIPT delete "$TEST_DIR/file1.txt" "$TEST_DIR/file2.txt" "$TEST_DIR/file3.txt" > /dev/null

    $SCRIPT empty --force > /dev/null
    assert_success "Empty recycle bin with --force"

    [ $(wc -l < "$METADATA_FILE") -le 2 ] && echo "✓ Metadata file is empty" || echo "✗ Metadata file not empty"
    [ $(ls -A "$FILES_DIR" | wc -l) -eq 0 ] && echo "✓ Files directory is empty" || echo "✗ Files directory not empty"

}
test_empty_force

test_empty_specific_file_force() {
    echo -e "\n________Test: Emptying specific file from recycle bin with --force________"
    setup > /dev/null

    echo "file A" > "$TEST_DIR/fileA.txt"
    echo "file B" > "$TEST_DIR/fileB.txt"
    echo "file C" > "$TEST_DIR/fileC.txt"

    $SCRIPT delete "$TEST_DIR/fileA.txt" "$TEST_DIR/fileB.txt" "$TEST_DIR/fileC.txt" > /dev/null


    local file_id=$(sed -n '4p' "$METADATA_FILE" | cut -d"$METADATA_DELIMITER" -f1)

    $SCRIPT empty "$file_id" --force > /dev/null
    assert_success "Empty specific file from recycle bin with --force"

    [ $(grep -c "^$file_id," "$METADATA_FILE") -eq 0 ] && echo "✓ Specific file metadata removed" || echo "✗ Specific file metadata still exists"
    [ ! -f "$FILES_DIR/$file_id" ] && echo "✓ Specific file removed from files directory" || echo "✗ Specific file still exists in files directory"
}
test_empty_specific_file_force

test_empty_specific_file() {
    echo -e "\n________Test: Emptying specific file from recycle bin with confirmation________"
    setup > /dev/null

    echo "file A" > "$TEST_DIR/fileA.txt"
    echo "file B" > "$TEST_DIR/fileB.txt"
    echo "file C" > "$TEST_DIR/fileC.txt"

    $SCRIPT delete "$TEST_DIR/fileA.txt" "$TEST_DIR/fileB.txt" "$TEST_DIR/fileC.txt" > /dev/null
    local file_id=$(sed -n '4p' "$METADATA_FILE" |  cut -d"$METADATA_DELIMITER" -f1)

    echo "Y" | $SCRIPT empty "$file_id" > /dev/null
    assert_success "Empty specific file from recycle bin with confirmation"

    [ $(grep -c "^$file_id," "$METADATA_FILE") -eq 0 ] && echo "✓ Specific file metadata removed" || echo "✗ Specific file metadata still exists"
    [ ! -f "$FILES_DIR/$file_id" ] && echo "✓ Specific file removed from files directory" || echo "✗ Specific file still exists in files directory"
}
test_empty_specific_file

test_search_existing_files_ignore_case() {
    echo -e "\n_______ Test: Search Existing File with Ignore Case _______"
    setup > /dev/null

    echo "search content" > "$TEST_DIR/search_test.txt"
    $SCRIPT delete "$TEST_DIR/search_test.txt" > /dev/null

    echo "search content" > "$TEST_DIR/Search_test.txt"
    $SCRIPT delete "$TEST_DIR/Search_test.txt" > /dev/null

    mkdir "$TEST_DIR/another_search_test"
    $SCRIPT delete "$TEST_DIR/another_search_test" > /dev/null

    echo "search content" > "$TEST_DIR/search_but_no_test.txt"
    $SCRIPT delete "$TEST_DIR/search_but_no_test.txt" > /dev/null

    pattern="search_test"
    result=$($SCRIPT search -i "$pattern")
    assert_success "Search existing files with ignore case"
    [ $(echo "$result" | tail -n +2 | grep -cEi "$pattern") -eq 3 ] && echo "✓ Found matching files" || echo "✗ Wrong number of matching files found"
}
test_search_existing_files_ignore_case

test_search_with_complex_pattern() {
    echo -e "\n_______ Test: Search with Complex Pattern _______"
    setup > /dev/null

    echo "complex content" > "$TEST_DIR/begin_then_end.txt"
    $SCRIPT delete "$TEST_DIR/begin_then_end.txt" > /dev/null

    mkdir "$TEST_DIR/begin_1234_end"
    echo "complex content" > "$TEST_DIR/begin_1234_end/file.txt"
    $SCRIPT delete "$TEST_DIR/begin_1234_end" > /dev/null

    echo "complex content" > "$TEST_DIR/begin_9876_end.txt"
    $SCRIPT delete "$TEST_DIR/begin_9876_end.txt" > /dev/null

    echo "complex content" > "$TEST_DIR/begin_009a_end.txt"
    $SCRIPT delete "$TEST_DIR/begin_009a_end.txt" > /dev/null

    pattern="^[begin]+.*[0-8]{3}.*[dt]$"
    result=$($SCRIPT search "$pattern")
    assert_success "Search with complex pattern"
    [ $(echo "$result" | tail -n +2 | awk -F' +' '{print $2}' | grep -cE "$pattern") -eq 2 ] && echo "✓ Found matching files" || echo "✗ Wrong number of matching files found" # this validation doesn't work when pattern is only in ORIGINAL_PATH or FILENAME is too big 
}
test_search_with_complex_pattern

teardown

echo "========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "========================================="

[ $FAIL -eq 0 ] && exit 0 || exit 1