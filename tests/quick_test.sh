#!/bin/bash
# Quick test to verify CoWboi setup and basic functionality

set -euo pipefail

echo "=== CoWboi Quick Test ==="
echo

# Check if we're in the right directory
if [[ ! -f "../cowboi.sh" ]]; then
    echo "Error: cowboi.sh not found. Run this from the tests directory."
    exit 1
fi

# Test script is executable
if [[ ! -x "../cowboi.sh" ]]; then
    echo "Error: cowboi.sh is not executable"
    exit 1
fi

echo "✓ Main script found and executable"

# Test help output
if ../cowboi.sh 2>&1 | grep -q "Usage:"; then
    echo "✓ Help output working"
else
    echo "✗ Help output not working"
    exit 1
fi

# Test invalid arguments
if ! ../cowboi.sh invalid_mode /dev/null 2>/dev/null; then
    echo "✓ Invalid arguments properly rejected"
else
    echo "✗ Invalid arguments not properly rejected"
    exit 1
fi

# Check if running on btrfs
if df -T . | grep -q btrfs; then
    echo "✓ Running on btrfs filesystem"
    
    # Check for required tools
    if command -v lsattr >/dev/null 2>&1 && command -v chattr >/dev/null 2>&1; then
        echo "✓ Required tools (lsattr, chattr) available"
        
        # Create a test file
        TEST_FILE="quick_test_file"
        echo "Quick test content" > "$TEST_FILE"
        
        echo "✓ Test file created"
        
        # Test CoW disable
        echo -n "Testing CoW disable... "
        if ../cowboi.sh disable "$TEST_FILE"; then
            echo "✓"
        else
            echo "✗"
            exit 1
        fi
        
        # Test CoW enable
        echo -n "Testing CoW enable... "
        if ../cowboi.sh enable "$TEST_FILE"; then
            echo "✓"
        else
            echo "✗"
            exit 1
        fi
        
        # Cleanup
        rm -f "$TEST_FILE"
        echo "✓ Cleanup completed"
        
    else
        echo "⚠ Required tools (lsattr, chattr) not available - tests will be skipped"
    fi
else
    echo "⚠ Not running on btrfs - full tests will be skipped"
fi

echo
echo "=== Quick Test Complete ==="
echo "Run './run_tests.sh' for comprehensive testing"
