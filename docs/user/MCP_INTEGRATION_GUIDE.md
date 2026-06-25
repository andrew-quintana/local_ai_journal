# MCP Integration Guide

## Overview

The Model Context Protocol (MCP) integration allows LLM agents in Open WebUI to directly access and interact with your journal vault through secure MCP calls. This enables the AI to read, search, and write journal entries seamlessly.

## What is MCP?

MCP (Model Context Protocol) is a standard that allows AI models to securely access external tools and data sources. In our implementation, it provides the LLM agent with direct access to your encrypted journal vault.

## MCP Tools Available

The vault MCP server provides the following tools to the LLM agent:

### 1. **list_journal_files**
- **Purpose**: List all journal files in the vault
- **Parameters**: 
  - `pattern` (optional): File pattern to filter results (e.g., '*.md', '2024-*')
  - `recursive` (optional): Search subdirectories recursively (default: true)
- **Returns**: List of files with metadata (name, path, size, modified date)

### 2. **read_journal_file**
- **Purpose**: Read the contents of a specific journal file
- **Parameters**:
  - `file_path` (required): Path to the journal file relative to vault root
- **Returns**: File content and metadata

### 3. **search_journal_content**
- **Purpose**: Search for text content across all journal files
- **Parameters**:
  - `query` (required): Text to search for
  - `case_sensitive` (optional): Case-sensitive search (default: false)
  - `file_pattern` (optional): File pattern to limit search scope (default: '*.md')
- **Returns**: Search results with matching lines and file locations

### 4. **get_journal_metadata**
- **Purpose**: Get metadata about a journal file
- **Parameters**:
  - `file_path` (required): Path to the journal file
- **Returns**: File metadata (size, dates, type, etc.)

### 5. **write_journal_file**
- **Purpose**: Write content to a journal file (markdown files only)
- **Parameters**:
  - `file_path` (required): Path to the journal file
  - `content` (required): Content to write
  - `append` (optional): Append to existing file or overwrite (default: false)
- **Returns**: Write operation result

### 6. **create_journal_entry**
- **Purpose**: Create a new journal entry with timestamp
- **Parameters**:
  - `title` (required): Title for the journal entry
  - `content` (required): Content of the journal entry
  - `date` (optional): Date for the entry (YYYY-MM-DD format, defaults to today)
  - `category` (optional): Category/folder for the entry
- **Returns**: Created entry information

## Security Features

### Access Control
- **Read-Only by Default**: Most operations are read-only for security
- **Write Restrictions**: Only markdown files can be written
- **Path Validation**: All file paths are validated to prevent directory traversal
- **File Size Limits**: Maximum file size limits prevent resource abuse

### Network Security
- **Localhost-Only Binding**: MCP server only accessible from localhost
- **Container Isolation**: MCP server runs in isolated Docker container
- **No External Access**: No external network access allowed

### Data Protection
- **Encrypted Storage**: All journal data remains encrypted in the vault
- **Secure Mounting**: Vault is mounted securely with appropriate permissions
- **Audit Logging**: All MCP operations are logged for security monitoring

## Setup Instructions

### Prerequisites
1. **Docker Running**: Ensure Docker Desktop is running
2. **Vault Mounted**: Run `./bin/journals-up.sh` to mount the vault
3. **Python 3.11+**: Required for MCP server

### Installation

1. **Install MCP Dependencies**:
   ```bash
   ./src/mcp/mcp-integration.sh install
   ```

2. **Start MCP Server and Services**:
   ```bash
   ./src/mcp/mcp-integration.sh start
   ```

3. **Verify Installation**:
   ```bash
   ./src/mcp/mcp-integration.sh status
   ```

### Manual Setup

If you prefer to set up MCP manually:

1. **Start MCP Server**:
   ```bash
   ./src/mcp/mcp-server.sh start
   ```

2. **Start Docker Services**:
   ```bash
   cd src/docker
   docker-compose up -d
   ```

3. **Test Connection**:
   ```bash
   ./src/mcp/mcp-integration.sh test
   ```

## Usage Examples

### Example 1: List Recent Journal Entries
The LLM agent can use the `list_journal_files` tool to find recent entries:

```json
{
  "tool": "list_journal_files",
  "parameters": {
    "pattern": "2024-*.md",
    "recursive": true
  }
}
```

### Example 2: Search for Specific Content
The LLM agent can search across all journal files:

```json
{
  "tool": "search_journal_content",
  "parameters": {
    "query": "meeting notes",
    "case_sensitive": false,
    "file_pattern": "*.md"
  }
}
```

### Example 3: Create a New Journal Entry
The LLM agent can create new journal entries:

```json
{
  "tool": "create_journal_entry",
  "parameters": {
    "title": "Daily Reflection",
    "content": "Today I learned about MCP integration...",
    "date": "2024-01-18",
    "category": "daily"
  }
}
```

## Troubleshooting

### Common Issues

1. **MCP Server Not Starting**:
   - Check if Docker is running
   - Verify vault is mounted
   - Check logs: `./src/mcp/mcp-server.sh logs`

2. **Connection Refused**:
   - Ensure MCP server is running on port 8082
   - Check firewall settings
   - Verify localhost binding

3. **Permission Denied**:
   - Check vault mount permissions
   - Verify Docker volume access
   - Check file system permissions

### Debug Commands

```bash
# Check MCP server status
./src/mcp/mcp-integration.sh status

# View MCP server logs
./src/mcp/mcp-server.sh logs

# Test MCP connection
./src/mcp/mcp-integration.sh test

# Restart MCP services
./src/mcp/mcp-integration.sh restart
```

## Configuration

### MCP Server Configuration
Edit `src/mcp/mcp-server.conf` to customize:
- Vault path
- File size limits
- Allowed file extensions
- Logging settings

### Docker Configuration
Edit `src/docker/docker-compose.yml` to customize:
- MCP server port
- Resource limits
- Security settings
- Volume mounts

## Security Considerations

1. **Local Access Only**: MCP server is only accessible from localhost
2. **Container Isolation**: MCP server runs in isolated Docker container
3. **File Restrictions**: Only markdown files can be written
4. **Path Validation**: All file paths are validated
5. **Audit Logging**: All operations are logged

## Performance

- **Memory Usage**: MCP server uses ~256MB RAM
- **CPU Usage**: Minimal CPU usage when idle
- **File Limits**: 10MB maximum file size
- **Concurrent Requests**: Up to 10 concurrent requests

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review MCP server logs
3. Verify Docker and vault status
4. Check security validation reports

---

**Document Version**: 1.0  
**Created**: 2025-01-18  
**Type**: User Guide  
**Priority**: High

