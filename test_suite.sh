#!/bin/bash

# Test Suite for Recycle Bin System

# Global Configuration
RECYCLE_BIN_DIR="$HOME/.recycle_bin"
FILES_DIR="$RECYCLE_BIN_DIR/files"
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"
CONFIG_FILE="$RECYCLE_BIN_DIR/config"

SCRIPT="./recycle_bin.sh"
TEST_DIR="test_data"
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

# Test Cases
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

test_delete_file() {
    echo -e "\n_______ Test: Delete File _______"
    setup > /dev/null
    echo "test content" > "$TEST_DIR/test.txt"
    $SCRIPT delete "$TEST_DIR/test.txt" > /dev/null
    assert_success "Delete existing file"
    [ ! -f "$TEST_DIR/test.txt" ] && echo "✓ File removed from original location" || echo "✗ File still exists in original location"
}

test_delete_100_files() {
    echo -e "\n_______ Test: Delete 100 Files _______"
    setup > /dev/null
    for i in {1..100}; do
        echo "$i {0..500}" > "$TEST_DIR/file$i.txt"
    done
    $SCRIPT delete "$TEST_DIR"/file1.txt "$TEST_DIR/file"{2..100}.txt > /dev/null
    assert_success "Delete 100 files"
    for i in {1..100}; do
        [ ! -f "$TEST_DIR/file$i.txt" ] || { echo "✗ File file$i.txt still exists"; return; }
    done
    echo "✓ All 100 files removed from original location"
}

test_delete_empty_directory() {
    echo -e "\n_______ Test: Delete Empty Directory _______"
    setup > /dev/null
    mkdir -p "$TEST_DIR/empty_dir"
    $SCRIPT delete "$TEST_DIR/empty_dir" > /dev/null
    assert_success "Delete empty directory"
    [ ! -d "$TEST_DIR/empty_dir" ] && echo "✓ Directory removed from original location" || echo "✗ Directory still exists in original location"
}

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

test_delete_nonexistent_file() {
    echo -e "\n_______ Test: Delete Non-existent File _______"
    setup > /dev/null
    $SCRIPT delete "$TEST_DIR/nonexistent.txt" > /dev/null
    assert_fail "Delete non-existent file"
}

test_list_empty() {
    echo -e "\n_______ Test: List Empty Bin _______"
    setup > /dev/null
    [[ $($SCRIPT list | head -n 1) == "Recycle bin is empty" ]]
    assert_success "List empty recycle bin"
    [ $(wc -l < "$METADATA_FILE") -le 2 ] && echo "✓ Metadata file is empty" || echo "✗ Metadata file not empty"
    [ $(ls -A "$FILES_DIR" | wc -l) -eq 0 ] && echo "✓ Files directory is empty" || echo "✗ Files directory not empty"
}

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


# Run all tests
echo "========================================="
echo "  Recycle Bin Test Suite"
echo "========================================="

test_initialization
test_delete_file
#test_delete_100_files # time the execution
test_delete_empty_directory
test_delete_nonexistent_file
test_list_empty
test_restore_file
test_restore_to_nonexistent_directory

# Add more test functions here

teardown

echo "========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "========================================="

[ $FAIL -eq 0 ] && exit 0 || exit 1