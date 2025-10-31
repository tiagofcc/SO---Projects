#!/bin/bash
# test_recyclebin.sh - Automated testing script
RECYCLE_BIN_DIR="$HOME/.recycle_bin"
[[ "$1" == "del" ]] && {
    rm -rf "$RECYCLE_BIN_DIR"
    echo "Recycle bin reset."
    exit 0
}

echo "========== Testing Recycle Bin System =========="

# Test 1: Initialization
echo -e "\n________Test 1: Initialization________"
./recycle_bin.sh help
echo -e "________Test 1 Complete________"
chmod u+rwx "$RECYCLE_BIN_DIR"

# Test 2: Create test files
echo -e "\n________Test 2: Creating test files________"
mkdir -p test_data
echo "Sample content 0" > test_data/file0.txt
echo "Sample content 00" > test_data/file1.txt
echo "Sample content 000" > test_data/file2.txt
echo "Sample content 0000" > 'test_data/file!@#$%^&*.txt'
echo "Sample content 00000" > test_data/file_with_a_super_large_name.txt
mkdir test_data/subdir
echo {0..9999} > test_data/subdir/file3.txt
echo {0..9}{0..9}{0..9}{0..9} > test_data/subdir/file4.txt
echo {0..9}{0..9}{0..9}{0..9} > test_data/subdir/file5.txt
echo -e "________Test 2 Complete________"


# Test 3: Delete files
echo -e "\n________Test 3: Deleting files________"
./recycle_bin.sh delete test_data/file0.txt
./recycle_bin.sh delete test_data/file1.txt test_data/file2.txt test_data/file3.txt 'test_data/file!@#$%^&*.txt'
./recycle_bin.sh delete test_data/file_with_a_super_large_name.txt
./recycle_bin.sh delete test_data/subdir
echo -e "________Test 3 Complete________"

echo -e "\n________Test 3.5: restore with rename "
echo "Sample content 00000" > test_data/file_with_a_super_large_name.txt
ID=$(./recycle_bin.sh list | grep "restore_test" | awk '{print $1}')
./recycle_bin.sh restore "$ID"
echo -e "\n________Test 3.5: Complete________"


# Test 4: List contents
echo -e "\n________Test 4: Listing recycle bin________"
./recycle_bin.sh list
echo -e "________Test 4 Complete________"

# Test 5: Search
echo -e "\n________Test 5: Searching for files________"
./recycle_bin.sh search "file1"
echo -e "________Test 5 Complete________"

# Cleanup
rm -rf test_data
echo ""
echo "========== Tests Complete =========="
