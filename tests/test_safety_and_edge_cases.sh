#!/bin/bash
# Safety and Edge Case Tests for CoWboi
set -euo pipefail

# Source the test utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/run_tests.sh" || source "./tests/run_tests.sh"

# Test: Invalid arguments handling
test_invalid_arguments() {
    # Test no arguments
    if ../cowboi.sh 2>/dev/null; then
        log_test "FAIL" "Invalid Arguments - No Args" "Script should fail with no arguments"
    else
        log_test "PASS" "Invalid Arguments - No Args" "Correctly failed with no arguments"
    fi
    
    # Test invalid mode
    if ../cowboi.sh invalid_mode "$TEST_DIR/test_file" 2>/dev/null; then
        log_test "FAIL" "Invalid Arguments - Invalid Mode" "Script should fail with invalid mode"
    else
        log_test "PASS" "Invalid Arguments - Invalid Mode" "Correctly failed with invalid mode"
    fi
}

# Test: Non-existent file handling
test_nonexistent_file() {
    local nonexistent_file="$TEST_DIR/nonexistent_file"
    
    if [[ -e "$nonexistent_file" ]]; then
        rm -f "$nonexistent_file"
    fi
    
    if ../cowboi.sh enable "$nonexistent_file" 2>/dev/null; then
        log_test "FAIL" "Non-existent File" "Script should fail with non-existent file"
    else
        log_test "PASS" "Non-existent File" "Correctly failed with non-existent file"
    fi
}

# Test: Directory handling
test_directory_handling() {
    local test_dir="$TEST_DIR/directory_test"
    mkdir -p "$test_dir/subdir"
    
    # Create test files
    echo "File 1" > "$test_dir/file1.txt"
    echo "File 2" > "$test_dir/file2.txt"
    echo "File 3" > "$test_dir/subdir/file3.txt"
    
    # Test disable CoW on directory
    if ../cowboi.sh disable "$test_dir"; then
        assert_cow_status "$test_dir/file1.txt" "NOCOW" "Directory Test - File1 NOCOW"
        assert_cow_status "$test_dir/subdir/file3.txt" "NOCOW" "Directory Test - File3 NOCOW"
    else
        log_test "FAIL" "Directory Handling - Disable" "Failed to disable CoW on directory"
        return 1
    fi
}

# Main test execution
main() {
    echo "Running Safety and Edge Case Tests..."
    
    if ! check_btrfs_requirements; then
        log_test "SKIP" "Safety and Edge Cases" "Btrfs requirements not met"
        return 0
    fi
    
    test_invalid_arguments
    test_nonexistent_file
    test_directory_handling
    
    echo "Safety and Edge Case Tests completed."
}

main "$@"
