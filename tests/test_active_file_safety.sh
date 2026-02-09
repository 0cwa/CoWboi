#!/bin/bash
# Active File Safety Tests for CoWboi
set -euo pipefail

# Source the test utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/run_tests.sh" || source "./tests/run_tests.sh"

# Test: File with concurrent writes (simulated)
test_concurrent_writes_simulation() {
    local test_file="$TEST_DIR/concurrent_writes_test"
    echo "Initial content" > "$test_file"
    
    # Start a background process that writes to the file
    (
        for i in {1..5}; do
            sleep 0.1
            echo "Write $i at $(date)" >> "$test_file"
        done
    ) &
    local writer_pid=$!
    
    sleep 0.05  # Let the writer start
    
    # Try to disable CoW while file is being written to
    if ../cowboi.sh disable "$test_file"; then
        # Wait for writer to finish
        wait $writer_pid 2>/dev/null || true
        
        # Verify file still exists and has correct attributes
        assert_file_exists "$test_file" "Concurrent Writes - File Exists"
        assert_cow_status "$test_file" "NOCOW" "Concurrent Writes - NOCOW Set"
        
        # Verify file is not corrupted (has at least original content)
        if grep -q "Initial content" "$test_file"; then
            log_test "PASS" "Concurrent Writes Simulation" "File handled safely during writes"
        else
            log_test "FAIL" "Concurrent Writes Simulation" "Original content lost"
            return 1
        fi
    else
        # Kill the writer process if the operation failed
        kill $writer_pid 2>/dev/null || true
        wait $writer_pid 2>/dev/null || true
        log_test "FAIL" "Concurrent Writes Simulation" "Failed to handle concurrent writes"
        return 1
    fi
}

# Main test execution
main() {
    echo "Running Active File Safety Tests..."
    
    if ! check_btrfs_requirements; then
        log_test "SKIP" "Active File Safety" "Btrfs requirements not met"
        return 0
    fi
    
    test_concurrent_writes_simulation
    
    echo "Active File Safety Tests completed."
}

main "$@"
