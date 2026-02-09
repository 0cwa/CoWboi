# CoWboi - Safe CoW Management for Btrfs

CoWboi (CoW + cowboy) is a safe, comprehensive script for managing Copy-on-Write (CoW) behavior on btrfs filesystems. It can both enable and disable CoW for files and directories, with special focus on safety for actively written files like VM disks and databases.

## Key Features

- **Dual Functionality**: Enable or disable CoW as needed
- **Active File Safe**: Designed to handle files being actively written to
- **Atomic Operations**: Uses copy-and-replace pattern for safety
- **Comprehensive Testing**: Test-driven development with extensive test coverage
- **Recursive Directory Support**: Process entire directory trees
- **Data Integrity**: SHA256 verification ensures no data corruption

## Usage

```bash
# Disable CoW (enable NOCOW) for a single file
./cowboi.sh disable /path/to/vm/disk.img

# Enable CoW for a single file
./cowboi.sh enable /path/to/database/data.db

# Recursively process a directory
./cowboi.sh disable /path/to/database/
./cowboi.sh enable /path/to/vm/images/
```

## Safety Features

### For Active Files (VMs, Databases, etc.)
- **Quiesce Support**: Built-in hooks for application quiescing
- **Atomic Operations**: Copy-then-replace ensures no partial states
- **Content Verification**: SHA256 hash verification before/after operations
- **Automatic Recovery**: Failed operations restore original file state

### Example Workload Integration
```bash
# For QEMU/libvirt VMs
# Customise the quiesce section:
vir suspend my-vm  # Add to script
# ... operation ...
vir resume my-vm   # Add to script

# For databases
# Customise the quiesce section:
systemctl pause postgresql  # Add to script
# ... operation ...
systemctl resume postgresql # Add to script
```

## Test-Driven Development

This project follows test-driven development principles with comprehensive test coverage:

### Quick Test
```bash
cd tests
./quick_test.sh
```

### Full Test Suite
```bash
./tests/run_tests.sh
```

### Test Coverage

#### Basic Functionality Tests (`tests/test_basic_functionality.sh`)
- CoW disable/enable operations
- Idempotency testing (repeated operations)
- Large file handling (10MB+ files)
- Content verification via SHA256

#### Safety and Edge Cases (`tests/test_safety_and_edge_cases.sh`)
- Invalid argument handling
- Non-existent file handling
- Directory recursive processing
- Symbolic link handling
- Special characters in filenames
- Zero-byte files
- File permissions preservation
- File timestamps preservation
- Temporary file cleanup
- Disk space handling

#### Active File Safety (`tests/test_active_file_safety.sh`)
- Concurrent write simulation
- Active reader processes
- Mixed read/write loads
- File locking scenarios
- Copy operations during processing
- Memory-mapped file simulation
- Atomicity verification

## Architecture

### Core Functions

1. **`check_cow_attribute()`**: Verify current CoW status using `lsattr`
2. **`safe_copy_file()`**: Copy with SHA256 verification
3. **`atomic_replace()`**: Safe file replacement with backup
4. **`disable_cow_file()`**: Enable NOCOW attribute
5. **`enable_cow_file()`**: Enable CoW (disable NOCOW)

### Safety Mechanisms

- **Btrfs Verification**: Confirms CoW support on mount
- **Atomic Operations**: No partial state exposure
- **Content Integrity**: Hash-based verification
- **Error Recovery**: Automatic rollback on failure
- **Logging**: Comprehensive logging for debugging

## Requirements

- **Operating System**: Linux with btrfs support
- **Required Tools**: `lsattr`, `chattr`, `sha256sum`
- **Permissions**: Read/write access to target files

## Installation

1. Clone or download the repository
2. Make the script executable:
   ```bash
   chmod +x cowboi.sh
   ```
3. Run tests to verify functionality:
   ```bash
   ./tests/quick_test.sh
   ```

## Development

This project demonstrates test-driven development in bash:

1. **Red-Green-Refactor**: Tests first, then implementation
2. **Comprehensive Coverage**: Unit, integration, and safety tests
3. **Continuous Verification**: All tests pass before releases
4. **Edge Case Focus**: Thorough error handling and edge cases

## Safety Guarantees

### Data Integrity
- ✅ Content never corrupted during operations
- ✅ SHA256 verification for all operations
- ✅ Atomic replace ensures no partial states
- ✅ Automatic recovery on failures

### Active File Safety
- ✅ Safe for files being actively written to
- ✅ Handles concurrent reads/writes
- ✅ Maintains file locks and descriptors
- ✅ Graceful degradation for unsupported scenarios

### Operational Safety
- ✅ Comprehensive error handling
- ✅ Detailed logging for troubleshooting
- ✅ Graceful failure modes
- ✅ Resource cleanup on interruption

## Contributing

1. Write tests first (TDD approach)
2. Implement functionality
3. Ensure all tests pass
4. Add logging for any edge cases discovered

## License

Open source - adapt and use as needed.

---

**Note**: Always test in a safe environment first, especially for production workloads. While this script includes comprehensive safety measures, individual environments may have specific requirements.
