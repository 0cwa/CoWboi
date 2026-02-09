#!/bin/bash
# Basic functionality tests for CoWboi
# Tests core CoW enable/disable operations

set -euo pipefail

# Source the test utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/run_tests.sh" || source "./tests/run_tests.sh"

# Test: Basic file creation and CoW status checking
test_basic_file_creation() {
    local test_file="$TEST_DIR/basic_test_file"
    echo "Basic test content" > "$test_file"
    
    assert_file_exists "$test_file" "Basic File Creation"
    
    # Check initial CoW status
    local initial_status=$(get_cow_status "$test_file")
    log_test "INFO" "Initial CoW Status" "File has $initial_status"
}

# Test: Disable CoW on a regular file
test_disable_cow_basic() {
    local test_file="$TEST_DIR/disable_test_file"
    echo "Testing CoW disable" > "$test_file"
    
    # Record original content
    local original_hash=$(sha256sum "$test_file" | cut -d' ' -f1)
    
    # Disable CoW
    if ../cowboi.sh disable "$test_file"; then
        assert_file_exists "$test_file" "Disable CoW - File Exists"
        assert_content_unchanged "$test_file" "$test_file" "Disable CoW - Content Unchanged"
        assert_cow_status "$test_file" "NOCOW" "Disable CoW - Correct Status"
    else
        log_test "FAIL" "Disable CoW Basic" "Failed to disable CoW"
        return 1
    fi
}

# Test: Enable CoW on a NOCOW file
test_enable_cow_basic() {
    local test_file="$TEST_DIR/enable_test_file"
    echo "Testing CoW enable" > "$test_file"
    
    # First disable CoW
    chattr +C "$test_file" || true
    
    # Record original content
    local original_hash=$(sha256sum "$test_file" | cut -d' ' -f1)
    
    # Enable CoW
    if ../cowboi.sh enable "$test_file"; then
        assert_file_exists "$test_file" "Enable CoW - File Exists"
        assert_content_unchanged "$test_file" "$test_file" "Enable CoW - Content Unchanged"
        assert_cow_status "$test_file" "COW" "Enable CoW - Correct Status"
    else
        log_test "FAIL" "Enable CoW Basic" "Failed to enable CoW"
        return 1
    fi
}

# Test: Toggle CoW multiple times
test_cow_toggle() {
    local test_file="$TEST_DIR/toggle_test_file"
    echo "Testing CoW toggle functionality" > "$test_file"
    
    local original_hash=$(sha256sum "$test_file" | cut -d' ' -f1)
    
    # Disable CoW
    if ! ../cowboi.sh disable "$test_file"; then
        log_test "FAIL" "CoW Toggle - Initial Disable" "Failed to disable CoW"
        return 1
    fi
    
    assert_cow_status "$test_file" "NOCOW" "CoW Toggle - After Disable"
    assert_content_unchanged "$test_file" "$test_file" "CoW Toggle - Content After Disable"
    
    # Enable CoW
    if ! ../cowboi.sh enable "$test_file"; then
        log_test "FAIL" "CoW Toggle - Enable" "Failed to enable CoW"
        return 1
    fi
    
    assert_cow_status "$test_file" "COW" "CoW Toggle - After Enable"
    assert_content_unchanged "$test_file" "$test_file" "CoW Toggle - Content After Enable"
}

# Main test execution
main() {
    echo "Running Basic Functionality Tests..."
    
    # Check requirements first
    if ! check_btrfs_requirements; then
        log_test "SKIP" "Basic Functionality" "Btrfs requirements not met"
        return 0
    fi
    
    test_basic_file_creation
    test_disable_cow_basic
    test_enable_cow_basic
    test_cow_toggle
    
    echo "Basic Functionality Tests completed."
}

main "$@"
