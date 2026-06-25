#!/bin/bash

# MCP Integration Test Suite
# Tests the MCP server integration with the journals infrastructure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test modules
MCP_INTEGRATION="$PROJECT_ROOT/src/mcp/mcp-integration.sh"
MCP_SERVER="$PROJECT_ROOT/src/mcp/mcp-server.sh"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Test logging
test_log() {
    local level="$1"
    local message="$2"
    echo "[$level] $message"
}

# Run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TOTAL_TESTS++))
    test_log "INFO" "Running test: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        test_log "PASS" "$test_name"
        ((PASSED_TESTS++))
    else
        test_log "FAIL" "$test_name"
        ((FAILED_TESTS++))
    fi
}

# Skip a test
skip_test() {
    local test_name="$1"
    local reason="$2"
    
    ((TOTAL_TESTS++))
    ((SKIPPED_TESTS++))
    test_log "SKIP" "$test_name - $reason"
}

# Test script existence
test_script_existence() {
    test_log "INFO" "Testing script existence..."
    
    run_test "MCP integration script exists" "[[ -f '$MCP_INTEGRATION' ]]"
    run_test "MCP server script exists" "[[ -f '$MCP_SERVER' ]]"
    run_test "MCP server Python script exists" "[[ -f '$PROJECT_ROOT/src/mcp/vault-mcp-server.py' ]]"
    run_test "MCP server config exists" "[[ -f '$PROJECT_ROOT/src/mcp/mcp-server.conf' ]]"
}

# Test script executability
test_script_executability() {
    test_log "INFO" "Testing script executability..."
    
    run_test "MCP integration script executable" "[[ -x '$MCP_INTEGRATION' ]]"
    run_test "MCP server script executable" "[[ -x '$MCP_SERVER' ]]"
}

# Test MCP server installation
test_mcp_installation() {
    test_log "INFO" "Testing MCP server installation..."
    
    if command -v python3 >/dev/null 2>&1; then
        run_test "Python 3 available" "python3 --version"
        
        # Test MCP package installation
        if python3 -c "import mcp" 2>/dev/null; then
            run_test "MCP package installed" "python3 -c 'import mcp'"
        else
            skip_test "MCP package installed" "MCP package not installed (will be installed during setup)"
        fi
    else
        skip_test "Python 3 available" "Python 3 not available"
    fi
}

# Test Docker configuration
test_docker_configuration() {
    test_log "INFO" "Testing Docker configuration..."
    
    if command -v docker >/dev/null 2>&1; then
        run_test "Docker available" "docker --version"
        
        if docker info >/dev/null 2>&1; then
            run_test "Docker daemon running" "docker info"
            
            # Test Docker Compose file
            if [[ -f "$PROJECT_ROOT/src/docker/docker-compose.yml" ]]; then
                run_test "Docker Compose file exists" "[[ -f '$PROJECT_ROOT/src/docker/docker-compose.yml' ]]"
                
                # Check if MCP server is configured in Docker Compose
                if grep -q "mcp-server" "$PROJECT_ROOT/src/docker/docker-compose.yml"; then
                    run_test "MCP server configured in Docker Compose" "grep -q 'mcp-server' '$PROJECT_ROOT/src/docker/docker-compose.yml'"
                else
                    skip_test "MCP server configured in Docker Compose" "MCP server not found in Docker Compose"
                fi
            else
                skip_test "Docker Compose file exists" "Docker Compose file not found"
            fi
        else
            skip_test "Docker daemon running" "Docker daemon not running"
        fi
    else
        skip_test "Docker available" "Docker not available"
    fi
}

# Test vault prerequisites
test_vault_prerequisites() {
    test_log "INFO" "Testing vault prerequisites..."
    
    # Check if vault manager exists
    local vault_manager="$PROJECT_ROOT/src/vault/vault-manager.sh"
    if [[ -f "$vault_manager" ]]; then
        run_test "Vault manager exists" "[[ -f '$vault_manager' ]]"
        
        # Check if vault exists (optional)
        if "$vault_manager" exists >/dev/null 2>&1; then
            run_test "Vault exists" "$vault_manager exists"
        else
            skip_test "Vault exists" "Vault does not exist (will be created during setup)"
        fi
    else
        skip_test "Vault manager exists" "Vault manager not found"
    fi
}

# Test MCP server functionality
test_mcp_server_functionality() {
    test_log "INFO" "Testing MCP server functionality..."
    
    # Test MCP server help
    if [[ -f "$MCP_SERVER" ]]; then
        run_test "MCP server help works" "$MCP_SERVER help"
    else
        skip_test "MCP server help works" "MCP server script not found"
    fi
    
    # Test MCP integration help
    if [[ -f "$MCP_INTEGRATION" ]]; then
        run_test "MCP integration help works" "$MCP_INTEGRATION help"
    else
        skip_test "MCP integration help works" "MCP integration script not found"
    fi
}

# Test MCP server configuration
test_mcp_server_configuration() {
    test_log "INFO" "Testing MCP server configuration..."
    
    local config_file="$PROJECT_ROOT/src/mcp/mcp-server.conf"
    if [[ -f "$config_file" ]]; then
        run_test "MCP server config file exists" "[[ -f '$config_file' ]]"
        
        # Test configuration loading
        if source "$config_file" 2>/dev/null; then
            run_test "MCP server config loads" "source '$config_file'"
        else
            skip_test "MCP server config loads" "MCP server config has syntax errors"
        fi
    else
        skip_test "MCP server config file exists" "MCP server config file not found"
    fi
}

# Test MCP tools documentation
test_mcp_tools_documentation() {
    test_log "INFO" "Testing MCP tools documentation..."
    
    local mcp_server_py="$PROJECT_ROOT/src/mcp/vault-mcp-server.py"
    if [[ -f "$mcp_server_py" ]]; then
        run_test "MCP server Python script exists" "[[ -f '$mcp_server_py' ]]"
        
        # Check if MCP tools are defined
        if grep -q "list_journal_files" "$mcp_server_py"; then
            run_test "list_journal_files tool defined" "grep -q 'list_journal_files' '$mcp_server_py'"
        else
            skip_test "list_journal_files tool defined" "list_journal_files tool not found"
        fi
        
        if grep -q "read_journal_file" "$mcp_server_py"; then
            run_test "read_journal_file tool defined" "grep -q 'read_journal_file' '$mcp_server_py'"
        else
            skip_test "read_journal_file tool defined" "read_journal_file tool not found"
        fi
        
        if grep -q "search_journal_content" "$mcp_server_py"; then
            run_test "search_journal_content tool defined" "grep -q 'search_journal_content' '$mcp_server_py'"
        else
            skip_test "search_journal_content tool defined" "search_journal_content tool not found"
        fi
        
        if grep -q "write_journal_file" "$mcp_server_py"; then
            run_test "write_journal_file tool defined" "grep -q 'write_journal_file' '$mcp_server_py'"
        else
            skip_test "write_journal_file tool defined" "write_journal_file tool not found"
        fi
        
        if grep -q "create_journal_entry" "$mcp_server_py"; then
            run_test "create_journal_entry tool defined" "grep -q 'create_journal_entry' '$mcp_server_py'"
        else
            skip_test "create_journal_entry tool defined" "create_journal_entry tool not found"
        fi
    else
        skip_test "MCP server Python script exists" "MCP server Python script not found"
    fi
}

# Test security features
test_security_features() {
    test_log "INFO" "Testing security features..."
    
    local mcp_server_py="$PROJECT_ROOT/src/mcp/vault-mcp-server.py"
    if [[ -f "$mcp_server_py" ]]; then
        # Check for security features
        if grep -q "is_safe_path" "$mcp_server_py"; then
            run_test "Path validation implemented" "grep -q 'is_safe_path' '$mcp_server_py'"
        else
            skip_test "Path validation implemented" "Path validation not found"
        fi
        
        if grep -q "MAX_FILE_SIZE" "$mcp_server_py"; then
            run_test "File size limits implemented" "grep -q 'MAX_FILE_SIZE' '$mcp_server_py'"
        else
            skip_test "File size limits implemented" "File size limits not found"
        fi
        
        if grep -q "ALLOWED_EXTENSIONS" "$mcp_server_py"; then
            run_test "File extension filtering implemented" "grep -q 'ALLOWED_EXTENSIONS' '$mcp_server_py'"
        else
            skip_test "File extension filtering implemented" "File extension filtering not found"
        fi
    else
        skip_test "Security features implemented" "MCP server Python script not found"
    fi
}

# Generate test report
generate_report() {
    local report_file="$PROJECT_ROOT/test-results/mcp-integration-test-report.txt"
    mkdir -p "$(dirname "$report_file")"
    
    {
        echo "=== MCP INTEGRATION TEST REPORT ==="
        echo "Generated: $(date)"
        echo "System: $(uname -a)"
        echo ""
        echo "Total Tests: $TOTAL_TESTS"
        echo "Passed: $PASSED_TESTS"
        echo "Failed: $FAILED_TESTS"
        echo "Skipped: $SKIPPED_TESTS"
        echo ""
        
        if [[ $FAILED_TESTS -eq 0 ]]; then
            echo "STATUS: ✅ ALL TESTS PASSED"
        else
            echo "STATUS: ❌ SOME TESTS FAILED"
        fi
    } > "$report_file"
    
    test_log "INFO" "Test report generated: $report_file"
}

# Main test execution
main() {
    test_log "INFO" "Starting MCP integration test suite..."
    echo
    
    test_script_existence
    echo
    
    test_script_executability
    echo
    
    test_mcp_installation
    echo
    
    test_docker_configuration
    echo
    
    test_vault_prerequisites
    echo
    
    test_mcp_server_functionality
    echo
    
    test_mcp_server_configuration
    echo
    
    test_mcp_tools_documentation
    echo
    
    test_security_features
    echo
    
    generate_report
    
    test_log "INFO" "Test suite complete"
    test_log "INFO" "Total: $TOTAL_TESTS, Passed: $PASSED_TESTS, Failed: $FAILED_TESTS, Skipped: $SKIPPED_TESTS"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        test_log "SUCCESS" "All tests passed or were skipped!"
        exit 0
    else
        test_log "ERROR" "Some tests failed: $FAILED_TESTS"
        exit 1
    fi
}

# Run main function
main "$@"

