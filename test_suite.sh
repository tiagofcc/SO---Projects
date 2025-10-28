#!/bin/bash

# Test Suite for Recycle Bin System

# Global Configuration
RECYCLE_BIN_DIR="$HOME/.recycle_bin" 
FILES_DIR="$RECYCLE_BIN_DIR/files" 
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db" 
CONFIG_FILE="$RECYCLE_BIN_DIR/config"
LOG_FILE="$RECYCLE_BIN_DIR/recycle.log"

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
    [ -f "$LOG_FILE" ] && echo "✓ Log file created" || echo "✗ Log file missing"
}

test_delete_file() {
    echo -e "\n_______ Test: Delete File _______"
    setup > /dev/null
    echo "test content" > "$TEST_DIR/test.txt"
    $SCRIPT delete "$TEST_DIR/test.txt" > /dev/null
    assert_success "Delete existing file"
    [ ! -f "$TEST_DIR/test.txt" ] && echo "✓ File removed from original location"
}

test_list_empty() {
    echo -e "\n_______ Test: List Empty Bin _______"
    setup > /dev/null
    [[ $($SCRIPT list | tail -n 1) == "Recycle bin is empty" ]]
    assert_success "List empty recycle bin"
    [ $(wc -l < "$METADATA_FILE") -le 2 ] && echo "✓ Metadata file is empty" #
    [ $(ls -A "$FILES_DIR" 2>/dev/null | wc -l) -eq 0 ] && echo "✓ Files directory is empty" #
}

test_restore_file() {
    echo -e "\n_______ Test: Restore File _______"
    setup > /dev/null
    echo "test" > "$TEST_DIR/restore_test.txt"
    $SCRIPT delete "$TEST_DIR/restore_test.txt" > /dev/null

    # Get file ID from list
    ID=$($SCRIPT list | grep "restore_test" | awk '{print $1}')
    $SCRIPT restore "$ID"
    assert_success "Restore file"
    [ -f "$TEST_DIR/restore_test.txt" ] && echo "✓ File restored"
}

# Run all tests
echo "========================================="
echo "  Recycle Bin Test Suite"
echo "========================================="

test_initialization
test_delete_file
test_list_empty
test_restore_file

# Add more test functions here

teardown

echo "========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "========================================="

[ $FAIL -eq 0 ] && exit 0 || exit 1