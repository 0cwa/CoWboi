#!/bin/bash
# Test runner for CoWboi
# Runs all test suites and provides comprehensive coverage reporting

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test environment setup
TEST_DIR="/tmp/cowboi_test_$$"
BTRFS_TEST_FILE="$TEST_DIR/test_file"
BACKUP_MOUNT_INFO=""

log_test() {
    local status=$1
    local test_name=$2
    local message=$3
    
    ((TESTS_RUN++))
    
    if [[ "$status" == "PASS" ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}[PASS]${NC} $test_name"
    elif [[ "$status" == "FAIL" ]]; then
        ((TESTS_FAILED++))
        echo -e "${RED}[FAIL]${NC} $test_name: $message"
    elif [[ "$status" == "SKIP" ]]; then
        echo -e "${YELLOW}[SKIP]${NC} $test_name: $message"
    else
        echo -e "${BLUE}[INFO]${NC} $test_name: $message"
    fi
}

# Setup test environment
setup_test_env() {
    echo -e "${BLUE}[SETUP]${NC} Setting up test environment..."
    
    # Create test directory
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    # Create test file
    echo "Test content for CoWboi" > "$BTRFS_TEST_FILE"
    
    echo -e "${GREEN}[SETUP]${NC} Test environment ready at $TEST_DIR"
}

# Cleanup test environment
cleanup_test_env() {
    echo -e "${BLUE}[CLEANUP]${NC} Cleaning up test environment..."
    
    cd - >/dev/null
    
    # Clean up any temporary files
    find /tmp -name "*cowboi*" -type f -user "$USER" -exec rm -f {} + 2>/dev/null || true
    find /tmp -name "*.cowboi.*" -type f -user "$USER" -exec rm -f {} + 2>/dev/null || true
    
    # Remove test directory if it still exists
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
    
    echo -e "${GREEN}[CLEANUP]${NC} Test environment cleaned"
}

# Check if running on btrfs with CoW enabled
check_btrfs_requirements() {
    echo -e "${BLUE}[CHECK]${NC} Checking btrfs requirements..."
    
    # Check if we're on btrfs
    if ! df -T "$TEST_DIR" | grep -q btrfs; then
        log_test "SKIP" "Btrfs Requirements" "Not running on btrfs filesystem"
        return 1
    fi
    
    # Check if lsattr is available
    if ! command -v lsattr >/dev/null 2>&1; then
        log_test "SKIP" "Btrfs Requirements" "lsattr command not available"
        return 1
    fi
    
    # Check if chattr is available
    if ! command -v chattr >/dev/null 2>&1; then
        log_test "SKIP" "Btrfs Requirements" "chattr command not available"
        return 1
    fi
    
    log_test "PASS" "Btrfs Requirements" "All requirements satisfied"
    return 0
}

# Get file CoW status
get_cow_status() {
    local file=$1
    if lsattr "$file" 2>/dev/null | grep -q "^[[:print:]]*C[[:print:]]* "; then
        echo "NOCOW"
    else
        echo "COW"
    fi
}

# Assert file exists
assert_file_exists() {
    local file=$1
    local test_name=$2
    
    if [[ ! -f "$file" ]]; then
        log_test "FAIL" "$test_name" "File $file does not exist"
        return 1
    fi
    
    log_test "PASS" "$test_name" "File exists"
    return 0
}

# Assert file has expected CoW status
assert_cow_status() {
    local file=$1
    local expected=$2
    local test_name=$3
    
    local actual=$(get_cow_status "$file")
    
    if [[ "$actual" != "$expected" ]]; then
        log_test "FAIL" "$test_name" "Expected CoW status $expected, got $actual"
        return 1
    fi
    
    log_test "PASS" "$test_name" "CoW status is $expected as expected"
    return 0
}

# Assert file content is unchanged
assert_content_unchanged() {
    local original=$1
    local current=$2
    local test_name=$3
    
    local original_hash=$(sha256sum "$original" | cut -d' ' -f1)
    local current_hash=$(sha256sum "$current" | cut -d' ' -f1)
    
    if [[ "$original_hash" != "$current_hash" ]]; then
        log_test "FAIL" "$test_name" "Content changed: $original_hash vs $current_hash"
        return 1
    fi
    
    log_test "PASS" "$test_name" "Content unchanged"
    return 0
}

# Run individual test suite
run_test_suite() {
    local test_file=$1
    local test_name=$(basename "$test_file" .sh)
    
    echo -e "\n${BLUE}=== Running $test_name ===${NC}"
    
    if [[ -x "$test_file" ]]; then
        if bash "$test_file"; then
            echo -e "${GREEN}[$test_name]${NC} All tests passed"
            return 0
        else
            echo -e "${RED}[$test_name]${NC} Some tests failed"
            return 1
        fi
    else
        log_test "SKIP" "$test_name" "Test file not executable"
        return 1
    fi
}

# Main test runner
main() {
    echo -e "${BLUE}CoWboi Test Suite${NC}"
    echo -e "${BLUE}=====================${NC}\n"
    
    # Setup
    setup_test_env
    
    # Run tests
    local failed_suites=0
    
    for test_file in tests/test_*.sh; do
        if [[ -f "$test_file" ]]; then
            if ! run_test_suite "$test_file"; then
                ((failed_suites++))
            fi
        fi
    done
    
    # Cleanup
    cleanup_test_env
    
    # Summary
    echo -e "\n${BLUE}Test Summary${NC}"
    echo -e "${BLUE}=============${NC}"
    echo "Tests run: $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $failed_suites -eq 0 && $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Handle script interruption
trap cleanup_test_env EXIT

# Run main
main "$@"
